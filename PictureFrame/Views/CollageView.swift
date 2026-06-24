import SwiftUI

/// 여러 사진을 창의적인 콜라주 레이아웃으로 한 화면에 보여준다.
/// 같은 사진 수라도 장면마다 다른 배치(템플릿)가 번갈아 나와 사진 앱 PLAY 처럼 다채롭다.
struct CollageView: View {
    @ObservedObject var viewModel: FrameViewModel
    @EnvironmentObject private var settings: SettingsStore

    private var photos: [FramePhoto] {
        viewModel.collageBatch(count: settings.collageCount)
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
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(zip(photos.indices, photos)), id: \.1.id) { index, photo in
                            let cell = cellRect(at: index, in: geo.size)
                            AsyncPhotoView(photo: photo, contentMode: .fill, viewModel: viewModel)
                                .frame(width: cell.width, height: cell.height)
                                .clipped()
                                .offset(x: cell.minX, y: cell.minY)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.6), value: viewModel.currentIndex)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        viewModel.advance(by: settings.collageCount)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { viewModel.startSlideTimer(step: settings.collageCount) }
        .onDisappear { viewModel.stopSlideTimer() }
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
