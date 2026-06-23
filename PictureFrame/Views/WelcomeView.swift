import SwiftUI

/// 앨범이 선택되지 않았을 때 보여주는 온보딩 화면.
struct WelcomeView: View {
    @Binding var showSettings: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.08), Color(white: 0.14)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 80))
                    .foregroundStyle(.white.opacity(0.9))

                VStack(spacing: 8) {
                    Text("PictureFrame")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("iOS 사진 앨범과 Lightroom 앨범을\n아름다운 액자로 감상하세요")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Button {
                    showSettings = true
                } label: {
                    Label("앨범 선택하기", systemImage: "photo.stack.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
            }
            .padding()
        }
    }
}
