import UIKit

/// 로드된 이미지를 메모리에 캐싱해 재다운로드/재디코딩을 방지한다.
/// 액자 슬라이드쇼처럼 같은 사진을 반복 표시하는 경우 네트워크 비용과
/// Adobe API rate limit 부담을 크게 줄인다.
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // 대략적인 상한: 총 픽셀 비용 기준 200MB.
        cache.totalCostLimit = 200 * 1024 * 1024
        // 메모리 경고 시 자동 비움 (NSCache 기본 동작) + 명시적 구독.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clear),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    /// 사진 ID 와 대상 크기를 조합한 캐시 키.
    private func key(id: String, size: CGSize) -> NSString {
        // 크기를 50pt 버킷으로 양자화해 비슷한 크기 요청이 캐시를 공유하도록 한다.
        let w = Int(size.width / 50) * 50
        let h = Int(size.height / 50) * 50
        return "\(id)@\(w)x\(h)" as NSString
    }

    func image(for id: String, size: CGSize) -> UIImage? {
        cache.object(forKey: key(id: id, size: size))
    }

    func store(_ image: UIImage, for id: String, size: CGSize) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key(id: id, size: size), cost: cost)
    }

    @objc func clear() {
        cache.removeAllObjects()
    }
}
