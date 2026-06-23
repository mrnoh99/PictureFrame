import SwiftUI

/// Adobe Lightroom 연동에 필요한 Client ID 설정 안내 화면.
/// 실제 앱에서는 AppConfig.swift 의 clientID 를 직접 수정하거나,
/// 빌드 설정(xcconfig/Secrets.xcconfig)을 통해 주입한다.
struct LightroomSetupView: View {
    @EnvironmentObject private var lightroomAuth: LightroomAuthService
    @State private var isSigningIn = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 헤더
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "camera.filters")
                        .font(.system(size: 48))
                        .foregroundStyle(.accent)
                    Text("Adobe Lightroom 연동")
                        .font(.title2.bold())
                    Text("Lightroom 앨범의 사진을 액자에 표시하려면 Adobe Developer Console 에서 Client ID 를 발급받아 설정해야 합니다.")
                        .foregroundStyle(.secondary)
                }

                Divider()

                // 단계별 안내
                VStack(alignment: .leading, spacing: 16) {
                    SetupStep(number: 1, title: "Adobe Developer Console 접속",
                              detail: "developer.adobe.com/console 에서 새 프로젝트를 만드세요.")
                    SetupStep(number: 2, title: "Lightroom Services API 추가",
                              detail: "프로젝트 > Add API > Creative Cloud > Lightroom Services API 를 선택하세요.")
                    SetupStep(number: 3, title: "OAuth 리디렉션 URI 등록",
                              detail: "Redirect URI 에 다음을 추가하세요:\n\(AppConfig.Lightroom.redirectURI)")
                    SetupStep(number: 4, title: "Client ID 입력",
                              detail: "발급받은 API Key (Client ID) 를 AppConfig.swift 의 clientID 에 넣으세요.")
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                if AppConfig.Lightroom.isConfigured {
                    Button {
                        Task { await signIn() }
                    } label: {
                        Group {
                            if isSigningIn {
                                ProgressView()
                            } else {
                                Text(lightroomAuth.isAuthenticated ? "다시 로그인" : "Adobe 계정으로 로그인")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSigningIn)
                }
            }
            .padding()
        }
        .navigationTitle("Lightroom 설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signIn() async {
        isSigningIn = true
        error = nil
        defer { isSigningIn = false }
        do {
            try await lightroomAuth.signIn()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
