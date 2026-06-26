import SwiftUI

/// 앱의 최상위 화면. 설정이 완료되면 액자 화면으로 전환한다.
struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var lightroomAuth: LightroomAuthService
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false

    private let photoLib = PhotoLibraryService()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if settings.selectedAlbums.isEmpty {
                WelcomeView(showSettings: $showSettings)
            } else {
                frameView
            }

            // 항상 접근 가능한 설정 버튼 (액자 모드에서도 노출)
            if !settings.selectedAlbums.isEmpty {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding()
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(photoLib: photoLib)
        }
        .ignoresSafeArea()
        .onAppear(perform: syncMusic)
        .onChange(of: settings.musicEnabled) { _, _ in syncMusic() }
        .onChange(of: settings.musicTracks) { _, _ in syncMusic() }
        .onChange(of: settings.musicFolderTracks) { _, _ in syncMusic() }
        .onChange(of: settings.musicVolume) { _, newValue in audioPlayer.setVolume(newValue) }
        .onChange(of: settings.selectedAlbums.isEmpty) { _, _ in syncMusic() }
        .onChange(of: scenePhase) { _, phase in
            // 백그라운드 진입 시 일시정지, 복귀 시 재개.
            if phase == .active { syncMusic() } else { audioPlayer.pause() }
        }
    }

    /// 현재 상태에 따라 배경음악 재생/정지를 동기화한다.
    /// (액자가 표시 중이고 배경음악이 켜져 있으며 트랙이 있을 때만 재생)
    private func syncMusic() {
        let shouldPlay = settings.musicEnabled
            && settings.hasAnyMusic
            && !settings.selectedAlbums.isEmpty
        audioPlayer.setTracks(settings.musicURLs)
        audioPlayer.setVolume(settings.musicVolume)
        if shouldPlay {
            audioPlayer.start()
        } else {
            audioPlayer.stop()
        }
    }

    @ViewBuilder
    private var frameView: some View {
        let lightroomService = LightroomService(auth: lightroomAuth)
        let vm = FrameViewModel(settings: settings, photoLib: photoLib, lightroom: lightroomService)
        FrameContainerView(viewModel: vm)
    }
}
