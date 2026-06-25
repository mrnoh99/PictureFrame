import SwiftUI

/// DisplayMode 에 따라 슬라이드쇼 / 콜라주 / 그리드 뷰를 전환한다.
struct FrameContainerView: View {
    @StateObject var viewModel: FrameViewModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var weather: WeatherProvider

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.photos.isEmpty {
                emptyView
            } else {
                switch settings.displayMode {
                case .slideshow:
                    // 장수 1장 = 한 장씩 슬라이드쇼, 2장 이상 = 콜라주 형태.
                    if settings.isSinglePhotoShow {
                        SlideshowView(viewModel: viewModel)
                    } else {
                        CollageView(viewModel: viewModel)
                    }
                case .collage:   CollageView(viewModel: viewModel)   // 과거 설정 호환
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
        .task(id: settings.showWeather) {
            if settings.showWeather { weather.start() }
        }
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

    /// 현재 표시 방식/장수에 맞는 재생 타이머를 시작한다.
    /// 뷰 교체(콜라주↔단일) 시 onAppear/onDisappear 경합으로 타이머가 꺼지는 것을 막기 위해
    /// 컨테이너에서 일원화해 관리한다.
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
