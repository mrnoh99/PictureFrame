import Foundation
import UIKit

/// Lightroom Services API (v2) 와 통신하는 HTTP 클라이언트.
final class LightroomAPIClient {
    private let auth: LightroomAuthService
    private let session: URLSession

    init(auth: LightroomAuthService) {
        self.auth = auth
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - 카탈로그

    func fetchCatalog() async throws -> LightroomCatalog {
        let data = try await get(path: "/catalog")
        // /v2/catalog 는 카탈로그 객체를 래퍼 없이 직접 반환한다.
        return try Self.stripAndDecode(data, as: LightroomCatalog.self)
    }

    // MARK: - 앨범

    func fetchAlbums(catalogID: String) async throws -> [LightroomAlbum] {
        var albums: [LightroomAlbum] = []
        var after: String? = nil
        repeat {
            var params = ["subtype": "collection", "limit": "100"]
            if let cursor = after { params["after"] = cursor }
            let data = try await get(path: "/catalogs/\(catalogID)/albums", params: params)
            let list = try Self.stripAndDecode(data, as: LightroomAlbumList.self)
            albums.append(contentsOf: list.resources)
            // Link 헤더로 페이지네이션을 지원하지만 현재는 100개로 제한 충분.
            after = nil
        } while after != nil
        return albums
    }

    // MARK: - 자산

    func fetchAssets(catalogID: String, albumID: String) async throws -> [LightroomAsset] {
        var assets: [LightroomAsset] = []
        var after: String? = nil
        repeat {
            var params = ["limit": "100", "embed": "asset"]
            if let cursor = after { params["after"] = cursor }
            let data = try await get(
                path: "/catalogs/\(catalogID)/albums/\(albumID)/assets",
                params: params
            )
            let list = try Self.stripAndDecode(data, as: LightroomAssetList.self)
            assets.append(contentsOf: list.resources.map(\.asset))
            after = nil
        } while after != nil
        return assets
    }

    // MARK: - 렌디션(이미지) URL

    /// 특정 자산의 렌디션(썸네일 또는 원본) URL 을 반환한다.
    /// Lightroom API 의 유효한 렌디션 크기: thumbnail2x | 640 | 1280 | 2048 | fullsize
    func renditionURL(catalogID: String, assetID: String, size: String = "1280") -> URL? {
        URL(string: "\(AppConfig.Lightroom.apiBaseURL)/catalogs/\(catalogID)/assets/\(assetID)/renditions/\(size)")
    }

    func downloadImage(catalogID: String, assetID: String, targetSize: CGSize) async throws -> UIImage {
        let scale = await MainActor.run { UIScreen.main.scale }
        let maxDim = max(targetSize.width, targetSize.height) * scale
        // 유효한 렌디션 크기로만 매핑 (320 같은 비표준 크기는 404 를 유발).
        let renditionSize: String
        switch maxDim {
        case ..<700: renditionSize = "640"
        case 700..<1600: renditionSize = "1280"
        default: renditionSize = "2048"
        }

        guard let url = renditionURL(catalogID: catalogID, assetID: assetID, size: renditionSize) else {
            throw PhotoProviderError.imageUnavailable
        }

        let token = try await auth.validAccessToken()
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(AppConfig.Lightroom.clientID, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PhotoProviderError.imageUnavailable
        }
        guard let image = UIImage(data: data) else {
            throw PhotoProviderError.imageUnavailable
        }
        return image
    }

    // MARK: - HTTP 헬퍼

    private func get(path: String, params: [String: String] = [:]) async throws -> Data {
        guard var components = URLComponents(string: AppConfig.Lightroom.apiBaseURL + path) else {
            throw PhotoProviderError.server("잘못된 URL 경로: \(path)")
        }
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw PhotoProviderError.server("URL 생성 실패")
        }

        let token = try await auth.validAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(AppConfig.Lightroom.clientID, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PhotoProviderError.server("응답 없음")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PhotoProviderError.server("HTTP \(http.statusCode): \(body)")
        }
        return data
    }

    /// Lightroom API 응답에서 JSON 하이재킹 방지 접두사 `while (1) {}` 를 제거한다.
    private static func stripAndDecode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        var cleaned = data
        if let raw = String(data: data, encoding: .utf8), raw.hasPrefix("while") {
            let stripped = raw.drop(while: { $0 != "{" && $0 != "[" })
            cleaned = Data(stripped.utf8)
        }
        return try JSONDecoder().decode(type, from: cleaned)
    }
}
