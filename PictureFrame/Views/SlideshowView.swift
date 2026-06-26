import SwiftUI

/// 한 장씩 Ken Burns(팬/줌) 효과와 크로스페이드로 전환하는 슬라이드쇼 뷰.
/// 이전 사진을 그대로 둔 채 다음 사진을 그 위에 겹쳐 나타나게 해(레이어 누적),
/// 전환 도중 검은 화면이 끼어들지 않도록 한다.
struct SlideshowView: View {
    @ObservedObject var viewModel: FrameViewModel
    @EnvironmentObject private var settings: SettingsStore

    /// 화면에 쌓인 슬라이드 레이어. 마지막 항목이 맨 위(현재 사진).
    @State private var slides: [SlideItem] = []
    /// 슬라이드 고유 id 생성용 카운터.
    @State private var tick = 0
    /// 전환 후 이전 레이어 정리 작업.
    @State private var pruneTask: Task<Void, Never>?

    private let transitionDuration: TimeInterval = 0.9

    struct SlideItem: Identifiable {
        let id: Int        // 누적 카운터(고유)
        let index: Int     // viewModel.photos 인덱스(패턴/전환 선택용)
        let photo: FramePhoto
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ForEach(slides) { slide in
                KenBurnsPhotoView(
                    photo: slide.photo,
                    viewModel: viewModel,
                    enabled: settings.kenBurnsEnabled,
                    intensity: CGFloat(settings.kenBurnsIntensity),
                    duration: settings.slideInterval,
                    sequence: slide.index,
                    fitStyle: settings.slideshowFitStyle
                )
                // 삽입(나타날 때)에만 효과 적용 → 이전 레이어는 그대로 남아 겹쳐 보인다.
                // 제거는 즉시(.identity): 새 사진이 완전히 덮은 뒤라 보이지 않는다.
                .transition(.asymmetric(
                    insertion: settings.slideTransition.resolved(
                        pool: settings.selectedTransitions,
                        index: slide.index
                    ),
                    removal: .identity
                ))
            }
        }
        .gesture(swipeGesture)
        .ignoresSafeArea()
        .onAppear { syncInitialSlide() }
        .onChange(of: viewModel.currentIndex) { _, _ in pushCurrentSlide() }
        .onChange(of: viewModel.photos.count) { _, _ in resetSlides() }
    }

    /// 최초 진입 시 현재 사진을 첫 레이어로 깐다.
    private func syncInitialSlide() {
        guard slides.isEmpty, let photo = currentPhoto else { return }
        tick += 1
        slides = [SlideItem(id: tick, index: viewModel.currentIndex, photo: photo)]
    }

    /// 사진 목록이 바뀌면 레이어를 새로 시작한다.
    private func resetSlides() {
        pruneTask?.cancel()
        slides = []
        syncInitialSlide()
    }

    /// 다음 사진을 새 레이어로 얹고(겹침 전환), 전환이 끝나면 이전 레이어를 정리한다.
    private func pushCurrentSlide() {
        guard let photo = currentPhoto else { return }
        tick += 1
        let item = SlideItem(id: tick, index: viewModel.currentIndex, photo: photo)
        withAnimation(.easeInOut(duration: transitionDuration)) {
            slides.append(item)
        }
        pruneTask?.cancel()
        pruneTask = Task {
            try? await Task.sleep(nanoseconds: UInt64((transitionDuration + 0.05) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            // 맨 위 레이어만 남긴다(애니메이션 없이 즉시 → 보이지 않게 제거).
            if slides.count > 1 { slides = Array(slides.suffix(1)) }
        }
    }

    private var currentPhoto: FramePhoto? {
        guard viewModel.photos.indices.contains(viewModel.currentIndex) else { return nil }
        return viewModel.photos[viewModel.currentIndex]
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
    /// Ken Burns 강도(0~1). 패턴의 줌/팬 크기를 이 비율만큼만 적용한다.
    let intensity: CGFloat
    let duration: TimeInterval
    /// 현재 사진의 순번 — 패턴을 순서대로 선택하는 데 사용.
    let sequence: Int
    /// 채움 방식(블러 배경 / 비율 레터박스).
    let fitStyle: CollageFitStyle

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
                    // 사진 전체(.fit)를 표시 → 정지 시 사진이 잘리지 않음.
                    // 블러 방식: 여백을 블러 배경으로 채움 / 비율 방식: 검은 레터박스.
                    // Ken Burns 줌/팬은 전경에 적용되어 화면을 벗어날 수 있다(의도된 효과).
                    BlurFillLayer(
                        image: img,
                        foregroundScale: currentScale,
                        foregroundOffset: currentOffset,
                        showBlurBackground: fitStyle == .blurFill
                    )
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

    /// 강도를 반영한 줌 배율(1.0 = 효과 없음 기준에서 강도만큼 보간).
    private var currentScale: CGFloat {
        guard enabled else { return 1.0 }
        let base = atEnd ? pattern.endScale : pattern.startScale
        return 1 + (base - 1) * intensity
    }

    /// 강도를 반영한 이동량.
    private var currentOffset: CGSize {
        guard enabled else { return .zero }
        let base = atEnd ? pattern.endOffset : pattern.startOffset
        return CGSize(width: base.width * intensity, height: base.height * intensity)
    }
}
