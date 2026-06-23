import SwiftUI

/// 여러 사진을 모자이크 콜라주 레이아웃으로 한 화면에 보여준다.
/// 사진 수(collageCount)에 따라 자동으로 레이아웃이 바뀐다.
struct CollageView: View {
    @ObservedObject var viewModel: FrameViewModel
    @EnvironmentObject private var settings: SettingsStore

    private var photos: [FramePhoto] {
        viewModel.collageBatch(count: settings.collageCount)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if photos.isEmpty {
                ProgressView().tint(.white)
            } else {
                collageLayout(for: photos)
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            viewModel.advance()
                        }
                    }
            }
        }
        .ignoresSafeArea()
        .onAppear { viewModel.startSlideTimer() }
        .onDisappear { viewModel.stopSlideTimer() }
    }

    @ViewBuilder
    private func collageLayout(for photos: [FramePhoto]) -> some View {
        switch photos.count {
        case 1:
            singlePhoto(photos[0])
        case 2:
            HStack(spacing: 2) {
                photoCell(photos[0])
                photoCell(photos[1])
            }
        case 3:
            layout3(photos)
        case 4:
            layout4(photos)
        case 5:
            layout5(photos)
        default:
            layout6Plus(photos)
        }
    }

    // MARK: - 레이아웃 변형

    private func singlePhoto(_ photo: FramePhoto) -> some View {
        photoCell(photo)
    }

    private func layout3(_ photos: [FramePhoto]) -> some View {
        HStack(spacing: 2) {
            photoCell(photos[0])
            VStack(spacing: 2) {
                photoCell(photos[1])
                photoCell(photos[2])
            }
        }
    }

    private func layout4(_ photos: [FramePhoto]) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                photoCell(photos[0])
                photoCell(photos[1])
            }
            HStack(spacing: 2) {
                photoCell(photos[2])
                photoCell(photos[3])
            }
        }
    }

    private func layout5(_ photos: [FramePhoto]) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                photoCell(photos[0])
                photoCell(photos[1])
            }
            HStack(spacing: 2) {
                photoCell(photos[2])
                photoCell(photos[3])
                photoCell(photos[4])
            }
        }
    }

    private func layout6Plus(_ photos: [FramePhoto]) -> some View {
        let half = photos.count / 2
        let top = Array(photos.prefix(half))
        let bottom = Array(photos.suffix(from: half))
        return VStack(spacing: 2) {
            HStack(spacing: 2) {
                ForEach(top) { photoCell($0) }
            }
            HStack(spacing: 2) {
                ForEach(bottom) { photoCell($0) }
            }
        }
    }

    // MARK: - 개별 셀

    private func photoCell(_ photo: FramePhoto) -> some View {
        AsyncPhotoView(photo: photo, contentMode: .fill, viewModel: viewModel)
            .clipped()
    }
}
