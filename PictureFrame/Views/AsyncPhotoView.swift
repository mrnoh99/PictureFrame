import SwiftUI

/// FramePhoto 를 비동기로 로드해 표시하는 재사용 컴포넌트.
struct AsyncPhotoView: View {
    let photo: FramePhoto
    let contentMode: ContentMode
    @ObservedObject var viewModel: FrameViewModel

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if isLoading {
                    ProgressView().tint(.white.opacity(0.5))
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.white.opacity(0.3))
                        .font(.largeTitle)
                }
            }
            .clipped()
            .task(id: photo.id) {
                isLoading = true
                image = await viewModel.loadImage(for: photo, targetSize: geo.size)
                isLoading = false
            }
        }
    }
}
