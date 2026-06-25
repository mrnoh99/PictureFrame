import SwiftUI

/// 사진을 잘리지 않게 전체(.fit)로 보여주고, 남는 여백은 같은 사진의
/// 블러 처리된 꽉 찬(.fill) 배경으로 채우는 레이어.
/// 사진이 화면(셀) 밖으로 나가지 않으면서도 검은 여백이 보이지 않는다.
struct BlurFillLayer: View {
    let image: UIImage
    /// 전경(선명한 사진) 배율. 1.0 이면 사진 전체가 셀에 꽉 맞게 보이고,
    /// 1.0 을 넘으면(Ken Burns 줌) 일부가 셀 밖으로 확대된다(슬라이드쇼에서 허용).
    var foregroundScale: CGFloat = 1.0
    var foregroundOffset: CGSize = .zero
    /// 블러 배경 배율/이동(예: Ken Burns 모션).
    var backgroundScale: CGFloat = 1.0
    var backgroundOffset: CGSize = .zero
    var blurRadius: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                // 블러 배경 — 살짝 확대해 블러 가장자리 비침을 가린다.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(backgroundScale * 1.12)
                    .offset(backgroundOffset)
                    .clipped()
                    .blur(radius: blurRadius)
                    .overlay(Color.black.opacity(0.12))

                // 전경 — 사진 전체가 보이도록 .fit, 절대 셀 밖으로 나가지 않음.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(foregroundScale)
                    .offset(foregroundOffset)
            }
            .clipped()
        }
    }
}

/// FramePhoto 를 비동기로 로드해 블러-필 방식으로 표시하는 컴포넌트(콜라주 셀용).
struct BlurFillPhotoView: View {
    let photo: FramePhoto
    @ObservedObject var viewModel: FrameViewModel

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let img = image ?? viewModel.cachedImage(for: photo, targetSize: geo.size) {
                    BlurFillLayer(image: img, blurRadius: 18)
                } else {
                    ZStack {
                        Color.black
                        ProgressView().tint(.white.opacity(0.5))
                    }
                }
            }
            .task(id: photo.id) {
                if image == nil {
                    image = await viewModel.loadImage(for: photo, targetSize: geo.size)
                }
            }
        }
    }
}
