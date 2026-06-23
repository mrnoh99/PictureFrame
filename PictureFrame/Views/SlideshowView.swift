import SwiftUI

/// 한 장씩 Ken Burns(팬/줌) 효과와 크로스페이드로 전환하는 슬라이드쇼 뷰.
struct SlideshowView: View {
    @ObservedObject var viewModel: FrameViewModel
    @EnvironmentObject private var settings: SettingsStore

    /// 현재 표시 중인 사진 ID 를 추적해 애니메이션을 트리거한다.
    @State private var displayedIndex: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !viewModel.photos.isEmpty {
                let photo = viewModel.photos[viewModel.currentIndex]
                KenBurnsPhotoView(
                    photo: photo,
                    viewModel: viewModel,
                    enabled: settings.kenBurnsEnabled,
                    duration: settings.slideInterval
                )
                .id(viewModel.currentIndex)  // ID 변경 시 뷰 교체 → 크로스페이드
                .transition(.opacity.animation(.easeInOut(duration: 0.8)))
            }
        }
        .gesture(swipeGesture)
        .onAppear { viewModel.startSlideTimer() }
        .onDisappear { viewModel.stopSlideTimer() }
        .ignoresSafeArea()
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.width < -30 {
                    viewModel.advance()
                    viewModel.startSlideTimer()
                } else if value.translation.width > 30 {
                    viewModel.previous()
                    viewModel.startSlideTimer()
                }
            }
    }
}

/// Ken Burns 효과: 사진에 부드러운 팬/줌 애니메이션을 적용한다.
private struct KenBurnsPhotoView: View {
    let photo: FramePhoto
    @ObservedObject var viewModel: FrameViewModel
    let enabled: Bool
    let duration: TimeInterval

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(enabled ? scale : 1.0)
                        .offset(enabled ? offset : .zero)
                        .animation(
                            enabled ? .linear(duration: duration).delay(0.1) : nil,
                            value: scale
                        )
                        .clipped()
                } else {
                    ProgressView().tint(.white.opacity(0.4))
                }
            }
            .task(id: photo.id) {
                image = await viewModel.loadImage(for: photo, targetSize: geo.size)
                if enabled { startKenBurns() }
            }
        }
        .ignoresSafeArea()
    }

    private func startKenBurns() {
        // 랜덤하게 4가지 Ken Burns 패턴 중 하나를 선택
        let patterns: [(CGFloat, CGSize)] = [
            (1.15, CGSize(width: -20, height: -10)),
            (1.12, CGSize(width: 15, height: 10)),
            (1.18, CGSize(width: -10, height: 15)),
            (1.10, CGSize(width: 20, height: -15))
        ]
        let (targetScale, targetOffset) = patterns.randomElement()!
        scale = targetScale
        offset = targetOffset
    }
}
