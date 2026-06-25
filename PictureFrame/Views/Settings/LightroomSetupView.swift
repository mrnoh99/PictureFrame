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
                }

                if AppConfig.Lightroom.partnerApprovalPending {
                    pendingApprovalCard
                } else if AppConfig.Lightroom.isConfigured {
                    connectionStatus
                } else {
                    setupGuide
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                actionButtons
            }
            .padding()
        }
        .navigationTitle("Lightroom 설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 파트너 승인 대기 상태

    private var pendingApprovalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.title)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Adobe 파트너 승인 대기 중")
                        .font(.headline)
                    Text("Lightroom 연동은 Adobe의 파트너 API 승인 후 사용할 수 있습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 10) {
                Label("지금 사용 가능한 방법", systemImage: "lightbulb")
                    .font(.subheadline.bold())
                Text("• **iOS 사진 앨범**은 지금 바로 사용할 수 있습니다.\n• Lightroom 사진은 Lightroom 앱에서 기기 사진 앨범으로 내보낸 뒤, 해당 앨범을 추가해 표시할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - 연결 상태 (설정 완료 시)

    private var connectionStatus: some View {
        HStack(spacing: 12) {
            Image(systemName: lightroomAuth.isAuthenticated ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
                .font(.title2)
                .foregroundStyle(lightroomAuth.isAuthenticated ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(lightroomAuth.isAuthenticated ? "Adobe 계정에 연결됨" : "로그인 필요")
                    .font(.headline)
                Text(lightroomAuth.isAuthenticated
                     ? "Lightroom 앨범을 불러올 수 있습니다."
                     : "Adobe 계정으로 로그인하면 앨범을 선택할 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 설정 안내 (미설정 시)

    private var setupGuide: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Lightroom 앨범의 사진을 액자에 표시하려면 Adobe Developer Console 에서 OAuth Native App 자격 증명을 발급받아 설정해야 합니다.")
                .foregroundStyle(.secondary)

            Divider()

            SetupStep(number: 1, title: "Adobe Developer Console 접속",
                      detail: "developer.adobe.com/console 에서 새 프로젝트를 만드세요.")
            SetupStep(number: 2, title: "Lightroom Services API 추가",
                      detail: "프로젝트 > Add API > Creative Cloud > Lightroom Services API 를 선택하세요.")
            SetupStep(number: 3, title: "OAuth Native App 자격 증명 생성",
                      detail: "Redirect URI 는 Adobe 가 자동 생성합니다 (adobe+<hash>://adobeid/<client_id>).")
            SetupStep(number: 4, title: "AppConfig.swift 에 값 입력",
                      detail: "clientID, redirectURI, callbackScheme 을 발급된 값으로 설정하세요.")
        }
    }

    // MARK: - 액션 버튼

    @ViewBuilder
    private var actionButtons: some View {
        if AppConfig.Lightroom.isConfigured && !AppConfig.Lightroom.partnerApprovalPending {
            VStack(spacing: 12) {
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

                if lightroomAuth.isAuthenticated {
                    Button(role: .destructive) {
                        lightroomAuth.signOut()
                    } label: {
                        Text("로그아웃").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
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
