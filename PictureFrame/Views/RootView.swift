import SwiftUI

/// 앱의 최상위 화면. 설정이 완료되면 액자 화면으로 전환한다.
struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var lightroomAuth: LightroomAuthService
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var weather: WeatherProvider
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    /// 액자(play) 화면에서 설정 버튼 노출 여부. 화면을 터치하면 잠시 나타난다.
    @State private var controlsVisible = false
    @State private var hideControlsTask: Task<Void, Never>?

    private let photoLib = PhotoLibraryService()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if settings.selectedAlbums.isEmpty {
                WelcomeView(showSettings: $showSettings)
            } else {
                frameView
                    .onTapGesture {
                        if !settings.alwaysShowControls { revealControls() }
                    }
            }

            if !settings.selectedAlbums.isEmpty && (settings.alwaysShowControls || controlsVisible) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding()
                .transition(.opacity)
            }
        }
        .onChange(of: settings.alwaysShowControls) { _, always in
            if always { hideControlsTask?.cancel(); controlsVisible = false }
        }
        .fullScreenCover(isPresented: $showSettings) {
            // fullScreenCover 는 일부 iOS 버전에서 @EnvironmentObject 를 자동으로
            // 상속하지 않아 SettingsView 안에서 crash 가 발생한다 — 명시적으로 주입.
            SettingsView(photoLib: photoLib)
                .environmentObject(settings)
                .environmentObject(weather)
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

    /// 화면 터치 시 설정 버튼을 표시하고, 3초 후 자동으로 숨긴다.
    private func revealControls() {
        withAnimation { controlsVisible = true }
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { controlsVisible = false }
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
        let folderService = FolderPhotoService(settings: settings)
        let vm = FrameViewModel(settings: settings, photoLib: photoLib,
                                lightroom: lightroomService, folder: folderService)
        FrameContainerView(viewModel: vm)
    }
}
