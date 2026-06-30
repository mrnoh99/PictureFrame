import SwiftUI

/// DisplayMode 에 따라 슬라이드쇼 / 콜라주 / 그리드 뷰를 전환한다.
struct FrameContainerView: View {
    @StateObject var viewModel: FrameViewModel
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.photos.isEmpty {
                emptyView
            } else {
                switch settings.displayMode {
                case .slideshow:
                    if settings.isSinglePhotoShow {
                        SlideshowView(viewModel: viewModel)
                    } else {
                        CollageView(viewModel: viewModel)
                    }
                case .collage:   CollageView(viewModel: viewModel)
                case .grid:      GridGalleryView(viewModel: viewModel)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            WidgetOverlayView()
        }
        .task {
            await viewModel.reload()
            startAppropriateTimer()
        }
        .onAppear { startAppropriateTimer() }
        .onChange(of: settings.displayMode) { _, _ in startAppropriateTimer() }
        .onChange(of: settings.isSinglePhotoShow) { _, _ in startAppropriateTimer() }
        .onChange(of: viewModel.photos.count) { _, _ in startAppropriateTimer() }
        .onDisappear { viewModel.stopSlideTimer() }
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
    }

    private func startAppropriateTimer() {
        guard !viewModel.photos.isEmpty else { return }
        switch settings.displayMode {
        case .grid:
            viewModel.stopSlideTimer()
        case .slideshow:
            if settings.isSinglePhotoShow {
                viewModel.startSlideTimer()
            } else {
                viewModel.startCollageTimer()
            }
        case .collage:
            viewModel.startCollageTimer()
        }
    }

    private var loadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(.white)
                Text("사진을 불러오는 중…")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption)
            }
        }
    }

    private var emptyView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("사진이 없습니다")
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
