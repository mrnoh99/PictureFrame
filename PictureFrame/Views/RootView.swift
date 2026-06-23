import SwiftUI

/// 앱의 최상위 화면. 설정이 완료되면 액자 화면으로 전환한다.
struct RootView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var lightroomAuth: LightroomAuthService
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
        .sheet(isPresented: $showSettings) {
            SettingsView(photoLib: photoLib)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var frameView: some View {
        let lightroomService = LightroomService(auth: lightroomAuth)
        let vm = FrameViewModel(settings: settings, photoLib: photoLib, lightroom: lightroomService)
        FrameContainerView(viewModel: vm)
    }
}
