import SwiftUI

/// 여러 사진을 창의적인 콜라주 레이아웃으로 한 화면에 보여준다.
/// 장면 전환 시 이전 장면이 그대로 남아 있는 채 새 장면이 위에 겹쳐 나타나도록
/// SlideshowView 와 동일한 레이어 누적 방식을 사용한다.
struct CollageView: View {
    @ObservedObject var viewModel: FrameViewModel
    @EnvironmentObject private var settings: SettingsStore

    /// 화면에 쌓인 장면 레이어. 마지막 항목이 맨 위(현재 장면).
    @State private var collageSlides: [CollageSceneItem] = []
    /// 장면 고유 id 생성용 카운터.
    @State private var tick = 0
    /// 전환 후 이전 레이어 정리 작업.
    @State private var pruneTask: Task<Void, Never>?

    private let transitionDuration: TimeInterval = 0.9

    struct CollageSceneItem: Identifiable {
        let id: Int
        let index: Int          // 장면 인덱스(템플릿 변형·전환 효과 결정용)
        let photos: [FramePhoto]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if collageSlides.isEmpty {
                ProgressView().tint(.white)
            } else {
                ForEach(collageSlides) { scene in
                    collageScene(for: scene)
                        // 삽입에만 전환 효과, 제거는 즉시(.identity) — 이전 장면이 아래에서 보인다.
                        .transition(.asymmetric(
                            insertion: settings.slideTransition.resolved(
                                pool: settings.selectedTransitions,
                                index: scene.index
                            ),
                            removal: .identity
                        ))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { syncInitialScene() }
        .onChange(of: viewModel.currentIndex) { _, _ in pushCurrentScene() }
        .onChange(of: viewModel.photos.count) { _, _ in resetScenes() }
    }

    // MARK: - 장면 렌더링

    @ViewBuilder
    private func collageScene(for scene: CollageSceneItem) -> some View {
        let photos = scene.photos
        let tmpl = CollageLayouts.template(count: photos.count, variant: scene.index)

        GeometryReader { geo in
            let rects = sceneLayoutRects(photos: photos, template: tmpl, in: geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(photos.indices, photos)), id: \.1.id) { index, photo in
                    let cell = rects.indices.contains(index) ? rects[index] : .zero
                    collageCell(for: photo)
                        .frame(width: cell.width, height: cell.height)
                        .clipped()
                        .offset(x: cell.minX, y: cell.minY)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            let step = max(1, scene.photos.count)
            viewModel.advance(by: step)
            viewModel.startCollageTimer()
        }
        .ignoresSafeArea()
    }

    // MARK: - 레이어 관리

    private func syncInitialScene() {
        guard collageSlides.isEmpty else { return }
        let count = settings.collagePhotoCount(forScene: viewModel.currentIndex)
        let photos = viewModel.collageBatch(count: count)
        guard !photos.isEmpty else { return }
        tick += 1
        collageSlides = [CollageSceneItem(id: tick, index: viewModel.currentIndex, photos: photos)]
    }

    private func resetScenes() {
        pruneTask?.cancel()
        collageSlides = []
        syncInitialScene()
    }

    private func pushCurrentScene() {
        let count = settings.collagePhotoCount(forScene: viewModel.currentIndex)
        let photos = viewModel.collageBatch(count: count)
        guard !photos.isEmpty else { return }
        tick += 1
        let item = CollageSceneItem(id: tick, index: viewModel.currentIndex, photos: photos)
        withAnimation(.easeInOut(duration: transitionDuration)) {
            collageSlides.append(item)
        }
        pruneTask?.cancel()
        pruneTask = Task {
            try? await Task.sleep(nanoseconds: UInt64((transitionDuration + 0.05) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if collageSlides.count > 1 { collageSlides = Array(collageSlides.suffix(1)) }
        }
    }

    // MARK: - 셀 렌더링 · 레이아웃

    @ViewBuilder
    private func collageCell(for photo: FramePhoto) -> some View {
        switch settings.slideshowFitStyle {
        case .blurFill:
            BlurFillPhotoView(photo: photo, viewModel: viewModel)
        case .aspect:
            AsyncPhotoView(photo: photo, contentMode: .fill, viewModel: viewModel)
        }
    }

    private func sceneLayoutRects(photos: [FramePhoto], template: CollageTemplate, in size: CGSize) -> [CGRect] {
        switch settings.slideshowFitStyle {
        case .blurFill:
            return photos.indices.map { cellRect(at: $0, template: template, in: size) }
        case .aspect:
            let aspects = photos.map { $0.aspectRatio ?? (4.0 / 3.0) }
            return CollageLayouts.justified(aspects: aspects, in: size, spacing: 4)
        }
    }

    private func cellRect(at index: Int, template: CollageTemplate, in size: CGSize) -> CGRect {
        let cells = template.cells
        guard cells.indices.contains(index) else { return .zero }
        let unit = cells[index]
        let gap: CGFloat = 2
        return CGRect(
            x: unit.minX * size.width + gap / 2,
            y: unit.minY * size.height + gap / 2,
            width: unit.width * size.width - gap,
            height: unit.height * size.height - gap
        )
    }
}
