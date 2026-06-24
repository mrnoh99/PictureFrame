import UIKit
import CryptoKit

/// 로드된 이미지를 2단(메모리 + 디스크)으로 캐싱한다.
/// - 메모리(NSCache): 즉시 조회. 액자 슬라이드쇼 반복 시 재디코딩 방지.
/// - 디스크(Caches): 앱 재실행 후에도 유지 → Lightroom 사진 재다운로드 방지, Adobe rate limit 완화.
final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let ioQueue = DispatchQueue(label: "com.example.PictureFrame.imagecache.io", qos: .utility)
    private let directory: URL
    private let diskCapacity = 500 * 1024 * 1024   // 500MB

    private init() {
        memory.totalCostLimit = 200 * 1024 * 1024  // 200MB

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("PictureFrameImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        NotificationCenter.default.addObserver(
            self, selector: #selector(clearMemory),
            name: UIApplication.didReceiveMemoryWarningNotification, object: nil
        )

        // 시작 시 디스크 용량 초과분 정리(오래된 파일부터).
        ioQueue.async { [weak self] in self?.trimDiskIfNeeded() }
    }

    // MARK: - 키

    /// 사진 ID + 대상 크기를 50pt 버킷으로 양자화한 캐시 키.
    private func key(id: String, size: CGSize) -> String {
        let w = Int(size.width / 50) * 50
        let h = Int(size.height / 50) * 50
        return "\(id)@\(w)x\(h)"
    }

    private func fileURL(for key: String) -> URL {
        // 키를 SHA256 해시로 변환해 파일명에 사용(특수문자/길이 문제 회피).
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name).appendingPathExtension("jpg")
    }

    private func cost(of image: UIImage) -> Int {
        Int(image.size.width * image.size.height * image.scale * image.scale * 4)
    }

    // MARK: - 메모리 (동기, 빠름)

    /// 메모리 캐시만 조회한다. 메인 스레드에서 호출해도 안전.
    func memoryImage(for id: String, size: CGSize) -> UIImage? {
        memory.object(forKey: key(id: id, size: size) as NSString)
    }

    /// 메모리에만 저장(디스크에서 승격할 때 사용 — 디스크 재기록 방지).
    func storeMemory(_ image: UIImage, for id: String, size: CGSize) {
        memory.setObject(image, forKey: key(id: id, size: size) as NSString, cost: cost(of: image))
    }

    // MARK: - 디스크 (비동기, I/O)

    /// 디스크 캐시를 조회한다.
    func diskImage(for id: String, size: CGSize) async -> UIImage? {
        let url = fileURL(for: key(id: id, size: size))
        return await withCheckedContinuation { continuation in
            ioQueue.async {
                guard let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                // 접근 시각 갱신(LRU 정리용).
                try? FileManager.default.setAttributes(
                    [.modificationDate: Date()], ofItemAtPath: url.path
                )
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - 저장 (메모리 + 디스크)

    func store(_ image: UIImage, for id: String, size: CGSize) {
        let k = key(id: id, size: size)
        memory.setObject(image, forKey: k as NSString, cost: cost(of: image))

        let url = fileURL(for: k)
        ioQueue.async {
            guard let data = image.jpegData(compressionQuality: 0.85) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - 정리

    @objc func clearMemory() {
        memory.removeAllObjects()
    }

    /// 디스크 캐시 총량이 한도를 넘으면 수정시각이 오래된 파일부터 삭제(LRU).
    private func trimDiskIfNeeded() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }

        let entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                  let size = values.fileSize else { return nil }
            return (url, size, values.contentModificationDate ?? .distantPast)
        }

        var total = entries.reduce(0) { $0 + $1.1 }
        guard total > diskCapacity else { return }

        // 오래된 순으로 삭제.
        for entry in entries.sorted(by: { $0.2 < $1.2 }) {
            if total <= diskCapacity { break }
            try? fm.removeItem(at: entry.0)
            total -= entry.1
        }
    }
}
