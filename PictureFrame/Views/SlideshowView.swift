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
                    duration: settings.slideInterval,
                    sequence: viewModel.currentIndex
                )
                .id(viewModel.currentIndex)  // ID 변경 시 뷰 교체 → 전환 효과 적용
                .transition(settings.slideTransition.swiftUITransition(index: viewModel.currentIndex))
            }
        }
        .animation(.easeInOut(duration: 0.8), value: viewModel.currentIndex)
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

/// Ken Burns 한 장면의 시작/끝 상태(줌·이동).
private struct KenBurnsPattern {
    let startScale: CGFloat
    let startOffset: CGSize
    let endScale: CGFloat
    let endOffset: CGSize

    /// 순서대로 순환하는 패턴 시퀀스 (줌인 → 좌→우 팬 → 상→하 팬 → 줌아웃 → 대각 팬 → 우→좌 팬).
    static let ordered: [KenBurnsPattern] = [
        // 중앙 줌인
        .init(startScale: 1.0,  startOffset: .zero,
              endScale: 1.22, endOffset: .zero),
        // 좌 → 우 팬
        .init(startScale: 1.18, startOffset: CGSize(width: 40, height: 0),
              endScale: 1.18, endOffset: CGSize(width: -40, height: 0)),
        // 상 → 하 팬
        .init(startScale: 1.18, startOffset: CGSize(width: 0, height: 30),
              endScale: 1.18, endOffset: CGSize(width: 0, height: -30)),
        // 줌아웃
        .init(startScale: 1.25, startOffset: .zero,
              endScale: 1.05, endOffset: .zero),
        // 좌상 → 우하 대각 팬
        .init(startScale: 1.2,  startOffset: CGSize(width: 35, height: 25),
              endScale: 1.2,  endOffset: CGSize(width: -35, height: -25)),
        // 우 → 좌 팬 (살짝 줌인)
        .init(startScale: 1.1,  startOffset: CGSize(width: -40, height: 0),
              endScale: 1.2,  endOffset: CGSize(width: 40, height: 0))
    ]
}

/// Ken Burns 효과: 사진에 부드러운 팬/줌 애니메이션을 적용한다.
/// 패턴은 사진 순서(sequence)에 따라 정해진 순서로 순환한다.
private struct KenBurnsPhotoView: View {
    let photo: FramePhoto
    @ObservedObject var viewModel: FrameViewModel
    let enabled: Bool
    let duration: TimeInterval
    /// 현재 사진의 순번 — 패턴을 순서대로 선택하는 데 사용.
    let sequence: Int

    @State private var image: UIImage?
    @State private var atEnd = false

    private var pattern: KenBurnsPattern {
        KenBurnsPattern.ordered[((sequence % KenBurnsPattern.ordered.count) + KenBurnsPattern.ordered.count) % KenBurnsPattern.ordered.count]
    }

    var body: some View {
        GeometryReader { geo in
            // 메모리 캐시(prefetch)에 이미 있으면 첫 렌더부터 즉시 표시 →
            // 전환이 "검은 화면"이 아니라 실제 사진끼리 매끄럽게 이어진다.
            let displayImage = image ?? viewModel.cachedImage(for: photo, targetSize: geo.size)

            ZStack {
                Color.black

                if let img = displayImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(currentScale)
                        .offset(currentOffset)
                        .clipped()
                } else {
                    ProgressView().tint(.white.opacity(0.4))
                }
            }
            .task(id: photo.id) {
                // 캐시에 없을 때만 비동기 로드.
                if image == nil {
                    image = await viewModel.loadImage(for: photo, targetSize: geo.size)
                }
                // 끝 상태로 천천히 애니메이션(Ken Burns).
                if enabled {
                    atEnd = false
                    withAnimation(.easeInOut(duration: duration)) {
                        atEnd = true
                    }
                }
                // 다음 사진들을 미리 받아 전환 지연 제거.
                viewModel.prefetchUpcoming(targetSize: geo.size)
            }
        }
        .ignoresSafeArea()
    }

    private var currentScale: CGFloat {
        guard enabled else { return 1.0 }
        return atEnd ? pattern.endScale : pattern.startScale
    }

    private var currentOffset: CGSize {
        guard enabled else { return .zero }
        return atEnd ? pattern.endOffset : pattern.startOffset
    }
}
