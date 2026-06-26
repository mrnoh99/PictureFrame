import SwiftUI

/// 여러 사진을 창의적인 콜라주 레이아웃으로 한 화면에 보여준다.
/// 같은 사진 수라도 장면마다 다른 배치(템플릿)가 번갈아 나와 사진 앱 PLAY 처럼 다채롭다.
struct CollageView: View {
    @ObservedObject var viewModel: FrameViewModel
    @EnvironmentObject private var settings: SettingsStore

    /// 현재 장면(currentIndex)의 사진 수 — 고정 또는 범위 내 무작위.
    private var sceneCount: Int {
        settings.collagePhotoCount(forScene: viewModel.currentIndex)
    }

    private var photos: [FramePhoto] {
        viewModel.collageBatch(count: sceneCount)
    }

    /// 현재 장면에 사용할 템플릿 — currentIndex 에 따라 변형이 순환한다.
    private var template: CollageTemplate {
        CollageLayouts.template(count: photos.count, variant: viewModel.currentIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if photos.isEmpty {
                ProgressView().tint(.white)
            } else {
                GeometryReader { geo in
                    let rects = layoutRects(in: geo.size)
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(zip(photos.indices, photos)), id: \.1.id) { index, photo in
                            let cell = rects.indices.contains(index) ? rects[index] : .zero
                            collageCell(for: photo)
                                .frame(width: cell.width, height: cell.height)
                                .clipped()
                                .offset(x: cell.minX, y: cell.minY)
                                .transition(settings.slideTransition.resolved(
                                    pool: settings.selectedTransitions,
                                    index: viewModel.currentIndex + index
                                ))
                        }
                    }
                    .animation(.easeInOut(duration: 0.6), value: viewModel.currentIndex)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        viewModel.advance(by: max(1, sceneCount))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    /// 한 사진을 표시할 셀 뷰 — 채움 방식에 따라 달라진다.
    @ViewBuilder
    private func collageCell(for photo: FramePhoto) -> some View {
        switch settings.slideshowFitStyle {
        case .blurFill:
            // 사진 전체(.fit) + 남는 여백은 블러 배경으로 채움.
            BlurFillPhotoView(photo: photo, viewModel: viewModel)
        case .aspect:
            // 셀 비율 = 사진 비율이므로 .fill 로도 잘리지 않는다.
            AsyncPhotoView(photo: photo, contentMode: .fill, viewModel: viewModel)
        }
    }

    /// 채움 방식에 맞는 각 사진의 픽셀 사각형 배열.
    private func layoutRects(in size: CGSize) -> [CGRect] {
        switch settings.slideshowFitStyle {
        case .blurFill:
            return (0..<photos.count).map { cellRect(at: $0, in: size) }
        case .aspect:
            let aspects = photos.map { $0.aspectRatio ?? (4.0 / 3.0) }
            return CollageLayouts.justified(aspects: aspects, in: size, spacing: 4)
        }
    }

    /// 단위 좌표 셀을 실제 픽셀 사각형으로 변환(2pt 간격 적용).
    private func cellRect(at index: Int, in size: CGSize) -> CGRect {
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
