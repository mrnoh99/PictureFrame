import Foundation
import UIKit
import AuthenticationServices
import Combine
import CryptoKit

/// Adobe IMS(Identity Management System) 를 통한 OAuth 2.0 (PKCE) 인증을 담당한다.
/// 액세스 토큰/리프레시 토큰을 관리하고, 만료 시 자동 갱신한다.
@MainActor
final class LightroomAuthService: NSObject, ObservableObject {

    @Published private(set) var isAuthenticated = false
    @Published private(set) var lastError: String?

    private var accessToken: String?
    private var accessTokenExpiry: Date?

    private var refreshToken: String? {
        get { KeychainStore.get("lightroom_refresh_token") }
        set { KeychainStore.set(newValue, for: "lightroom_refresh_token") }
    }

    private var webAuthSession: ASWebAuthenticationSession?
    private var pkceVerifier: String?
    /// 진행 중인 인증 콜백을 이어주기 위한 continuation.
    private var pendingAuthContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        isAuthenticated = refreshToken != nil
    }

    // MARK: - 로그인 / 로그아웃

    /// 브라우저 기반 OAuth 로그인 플로우를 시작한다.
    func signIn() async throws {
        guard AppConfig.Lightroom.isConfigured else {
            throw PhotoProviderError.notConfigured
        }

        let verifier = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        pkceVerifier = verifier

        var components = URLComponents(string: AppConfig.Lightroom.authorizeURL)!
        components.queryItems = [
            .init(name: "client_id", value: AppConfig.Lightroom.clientID),
            .init(name: "scope", value: AppConfig.Lightroom.scopes),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: AppConfig.Lightroom.redirectURI),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            throw PhotoProviderError.server("잘못된 인증 URL")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.pendingAuthContinuation = continuation
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AppConfig.Lightroom.callbackScheme
            ) { [weak self] callbackURL, error in
                guard let self else { return }
                if let error {
                    self.finishAuth(.failure(error))
                    return
                }
                if let callbackURL {
                    Task { await self.exchangeCode(from: callbackURL) }
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            session.start()
        }
    }

    func signOut() {
        accessToken = nil
        accessTokenExpiry = nil
        refreshToken = nil
        isAuthenticated = false
    }

    /// `onOpenURL` 로 들어온 커스텀 스킴 리디렉션을 처리한다.
    /// (ASWebAuthenticationSession 의 콜백과 병행하여 안전망 역할)
    func handleRedirect(url: URL) {
        guard url.scheme == AppConfig.Lightroom.callbackScheme else { return }
        Task { await exchangeCode(from: url) }
    }

    // MARK: - 토큰 발급/갱신

    private func exchangeCode(from callbackURL: URL) async {
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            finishAuth(.failure(PhotoProviderError.server("인증 코드를 찾을 수 없습니다.")))
            return
        }

        var params = [
            "grant_type": "authorization_code",
            "client_id": AppConfig.Lightroom.clientID,
            "code": code,
            "redirect_uri": AppConfig.Lightroom.redirectURI
        ]
        if let verifier = pkceVerifier {
            params["code_verifier"] = verifier
        }

        do {
            try await requestToken(params: params)
            finishAuth(.success(()))
        } catch {
            finishAuth(.failure(error))
        }
    }

    /// 유효한 액세스 토큰을 반환한다. 만료되었으면 리프레시 토큰으로 갱신한다.
    func validAccessToken() async throws -> String {
        if let token = accessToken, let expiry = accessTokenExpiry, expiry > Date().addingTimeInterval(60) {
            return token
        }
        guard let refresh = refreshToken else {
            throw PhotoProviderError.notAuthenticated
        }
        try await requestToken(params: [
            "grant_type": "refresh_token",
            "client_id": AppConfig.Lightroom.clientID,
            "refresh_token": refresh
        ])
        guard let token = accessToken else {
            throw PhotoProviderError.notAuthenticated
        }
        return token
    }

    private func requestToken(params: [String: String]) async throws {
        var request = URLRequest(url: URL(string: AppConfig.Lightroom.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PhotoProviderError.server("토큰 요청 실패 (\(body))")
        }

        let token = try JSONDecoder().decode(IMSTokenResponse.self, from: data)
        accessToken = token.accessToken
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        if let newRefresh = token.refreshToken {
            refreshToken = newRefresh
        }
        isAuthenticated = true
    }

    private func finishAuth(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            lastError = nil
            pendingAuthContinuation?.resume()
        case .failure(let error):
            // 사용자가 취소한 경우는 조용히 처리.
            if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                pendingAuthContinuation?.resume()
            } else {
                lastError = error.localizedDescription
                pendingAuthContinuation?.resume(throwing: error)
            }
        }
        pendingAuthContinuation = nil
        webAuthSession = nil
        pkceVerifier = nil
    }

    // MARK: - PKCE 헬퍼

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

// MARK: - 프레젠테이션 컨텍스트

extension LightroomAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}

// MARK: - 응답 모델

private struct IMSTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

// MARK: - 유틸

extension Data {
    /// Base64 URL-safe 인코딩 (패딩 제거).
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "+&=?")
        return set
    }()
}
