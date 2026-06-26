import Foundation
import UIKit
import ImageIO

/// Files(파일) 앱의 폴더를 사진 출처로 사용하는 Provider.
/// 보안 스코프 북마크로 폴더 접근 권한을 유지하고, 폴더 안의 이미지 파일을
/// ImageIO 로 화면 크기에 맞춰 다운샘플링해 로드한다.
final class FolderPhotoService: PhotoProvider {
    let kind: PhotoSourceKind = .folder

    private let settings: SettingsStore
    /// 보안 스코프가 활성화된 폴더 URL (앨범ID → URL).
    private var activeFolders: [String: URL] = [:]
    private let lock = NSLock()

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "bmp", "webp"
    ]

    init(settings: SettingsStore) {
        self.settings = settings
    }

    deinit {
        for url in activeFolders.values { url.stopAccessingSecurityScopedResource() }
    }

    func fetchAlbums() async throws -> [Album] { [] }

    func fetchPhotos(in selection: AlbumSelection) async throws -> [FramePhoto] {
        guard let folder = resolveFolder(for: selection) else {
            throw PhotoProviderError.albumNotFound
        }
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls
            .filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
            .map { url in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return FramePhoto(
                    id: url.absoluteString,
                    source: .folder,
                    creationDate: date,
                    aspectRatio: Self.aspectRatio(of: url)
                )
            }
    }

    func loadImage(for photo: FramePhoto, targetSize: CGSize) async throws -> UIImage {
        guard let url = URL(string: photo.id) else { throw PhotoProviderError.imageUnavailable }
        // targetSize 는 포인트 단위. 레티나를 고려해 2배로 픽셀 한도를 잡는다.
        let maxDim = max(targetSize.width, targetSize.height) * 2
        guard let image = Self.downsampledImage(at: url, maxPixel: maxDim > 0 ? maxDim : 2048) else {
            throw PhotoProviderError.imageUnavailable
        }
        return image
    }

    // MARK: - 보안 스코프 폴더 해제

    private func resolveFolder(for selection: AlbumSelection) -> URL? {
        lock.lock(); defer { lock.unlock() }
        if let cached = activeFolders[selection.albumID] { return cached }
        guard let data = settings.folderBookmarks[selection.albumID] else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        if url.startAccessingSecurityScopedResource() {
            activeFolders[selection.albumID] = url
            return url
        }
        // 스코프 시작 실패해도 접근 가능한 경우가 있어 URL 은 반환.
        return url
    }

    // MARK: - ImageIO

    private static func aspectRatio(of url: URL) -> CGFloat? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat,
              h > 0 else { return nil }
        return w / h
    }

    private static func downsampledImage(at url: URL, maxPixel: CGFloat) -> UIImage? {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, srcOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}
