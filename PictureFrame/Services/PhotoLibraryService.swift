import Foundation
import Photos
import UIKit

/// PhotoKit 을 사용해 iOS 사진 보관함의 앨범과 사진을 제공한다.
final class PhotoLibraryService: PhotoProvider {
    let kind: PhotoSourceKind = .photoLibrary

    private let imageManager = PHCachingImageManager()
    /// FramePhoto.id -> PHAsset 매핑 (이미지 로드시 사용).
    private var assetIndex: [String: PHAsset] = [:]
    private let indexLock = NSLock()

    // MARK: - 권한

    /// 사진 보관함 읽기 권한을 요청하고 최종 상태를 반환한다.
    @discardableResult
    func requestAuthorization() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return current
    }

    private func ensureAuthorized() async throws {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            throw PhotoProviderError.notAuthorized
        }
    }

    // MARK: - 앨범

    func fetchAlbums() async throws -> [Album] {
        try await ensureAuthorized()

        var albums: [Album] = []

        // 사용자 생성 앨범
        let userCollections = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: nil
        )
        userCollections.enumerateObjects { collection, _, _ in
            albums.append(self.makeAlbum(from: collection))
        }

        // 스마트 앨범(즐겨찾기, 최근 항목 등) 중 유용한 것
        let smartSubtypes: [PHAssetCollectionSubtype] = [
            .smartAlbumUserLibrary, .smartAlbumFavorites, .smartAlbumRecentlyAdded
        ]
        for subtype in smartSubtypes {
            let smart = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: subtype, options: nil
            )
            smart.enumerateObjects { collection, _, _ in
                albums.append(self.makeAlbum(from: collection))
            }
        }

        return albums.filter { ($0.estimatedCount ?? 0) > 0 }
    }

    private func makeAlbum(from collection: PHAssetCollection) -> Album {
        let count = collection.estimatedAssetCount == NSNotFound
            ? nil : collection.estimatedAssetCount
        return Album(
            id: collection.localIdentifier,
            title: collection.localizedTitle ?? "제목 없음",
            source: .photoLibrary,
            estimatedCount: count
        )
    }

    // MARK: - 사진

    func fetchPhotos(in selection: AlbumSelection) async throws -> [FramePhoto] {
        try await ensureAuthorized()

        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [selection.albumID], options: nil
        )
        guard let collection = collections.firstObject else {
            throw PhotoProviderError.albumNotFound
        }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let assets = PHAsset.fetchAssets(in: collection, options: options)

        var photos: [FramePhoto] = []
        photos.reserveCapacity(assets.count)
        var newIndex: [String: PHAsset] = [:]

        assets.enumerateObjects { asset, _, _ in
            let ratio: CGFloat? = asset.pixelHeight > 0
                ? CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
                : nil
            let photo = FramePhoto(
                id: asset.localIdentifier,
                source: .photoLibrary,
                creationDate: asset.creationDate,
                aspectRatio: ratio
            )
            photos.append(photo)
            newIndex[asset.localIdentifier] = asset
        }

        indexLock.lock()
        for (key, value) in newIndex { assetIndex[key] = value }
        indexLock.unlock()

        return photos
    }

    // MARK: - 이미지 로드

    func loadImage(for photo: FramePhoto, targetSize: CGSize) async throws -> UIImage {
        indexLock.lock()
        let cached = assetIndex[photo.id]
        indexLock.unlock()

        let asset: PHAsset
        if let cached {
            asset = cached
        } else {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [photo.id], options: nil)
            guard let found = result.firstObject else {
                throw PhotoProviderError.imageUnavailable
            }
            indexLock.lock(); assetIndex[photo.id] = found; indexLock.unlock()
            asset = found
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true   // iCloud 사진 다운로드 허용
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: pixelSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // 저해상도 중간 콜백은 무시하고 최종 이미지만 사용.
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return
                }
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: PhotoProviderError.imageUnavailable)
                }
            }
        }
    }
}
