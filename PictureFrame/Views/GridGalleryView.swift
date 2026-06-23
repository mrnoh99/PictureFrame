import SwiftUI

/// 사진 전체를 격자 형식으로 스크롤해서 볼 수 있는 갤러리 뷰.
/// 셀을 탭하면 전체화면 슬라이드쇼로 이동한다.
struct GridGalleryView: View {
    @ObservedObject var viewModel: FrameViewModel
    @State private var selectedPhoto: FramePhoto?

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 2)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(viewModel.photos) { photo in
                        AsyncPhotoView(photo: photo, contentMode: .fill, viewModel: viewModel)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            .onTapGesture {
                                selectedPhoto = photo
                            }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullscreenPhotoView(photo: photo, viewModel: viewModel)
        }
    }
}

/// 그리드에서 탭한 사진을 전체화면으로 보여주는 뷰.
private struct FullscreenPhotoView: View {
    let photo: FramePhoto
    @ObservedObject var viewModel: FrameViewModel
    @State private var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .task {
            image = await viewModel.loadImage(for: photo, targetSize: CGSize(width: 1200, height: 1200))
        }
    }
}
