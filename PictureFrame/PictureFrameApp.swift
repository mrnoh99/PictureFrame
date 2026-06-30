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
                    lightroomAuth.handleRedirect(url: url)
                }
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
