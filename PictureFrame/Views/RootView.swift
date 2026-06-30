import SwiftUI

/// 앱의 최상위 화면. 설정이 완료되면 액자 화면으로 전환한다.
struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var lightroomAuth: LightroomAuthService
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var controlsVisible = false
    @State private var hideControlsTask: Task<Void, Never>?

    private let photoLib = PhotoLibraryService()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if settings.selectedAlbums.isEmpty {
                WelcomeView(showSettings: $showSettings)
            } else {
                frameView
                    .onTapGesture { revealControls() }
            }

            if !settings.selectedAlbums.isEmpty && controlsVisible {
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
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(photoLib: photoLib)
                .environmentObject(settings)
        }
        .ignoresSafeArea()
        .onAppear(perform: syncMusic)
        .onChange(of: settings.musicEnabled) { _, _ in syncMusic() }
        .onChange(of: settings.musicTracks) { _, _ in syncMusic() }
        .onChange(of: settings.musicFolderTracks) { _, _ in syncMusic() }
        .onChange(of: settings.musicVolume) { _, newValue in audioPlayer.setVolume(newValue) }
        .onChange(of: settings.selectedAlbums.isEmpty) { _, _ in syncMusic() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { syncMusic() } else { audioPlayer.pause() }
        }
    }

    private func revealControls() {
        withAnimation { controlsVisible = true }
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { controlsVisible = false }
        }
    }

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
