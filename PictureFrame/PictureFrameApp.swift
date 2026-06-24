import SwiftUI

@main
struct PictureFrameApp: App {
    @StateObject private var settings = SettingsStore()
    @StateObject private var lightroomAuth = LightroomAuthService()
    @StateObject private var audioPlayer = AudioPlayerService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(lightroomAuth)
                .environmentObject(audioPlayer)
                .onOpenURL { url in
                    // Adobe IMS OAuth 리디렉션 콜백 처리
                    lightroomAuth.handleRedirect(url: url)
                }
                .onAppear {
                    // 액자 모드에서 화면이 꺼지지 않도록 유지
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
