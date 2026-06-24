import Foundation
import UIKit

/// Lightroom 앨범과 사진을 PhotoProvider 인터페이스로 노출한다.
final class LightroomService: PhotoProvider {
    let kind: PhotoSourceKind = .lightroom

    private let api: LightroomAPIClient
    private let auth: LightroomAuthService
    /// 자산 ID → 카탈로그 ID 역매핑 (이미지 로드시 필요).
    private var assetCatalogMap: [String: String] = [:]
    private let mapLock = NSLock()

    init(auth: LightroomAuthService) {
        self.auth = auth
        self.api = LightroomAPIClient(auth: auth)
    }

    // MARK: - 앨범

    func fetchAlbums() async throws -> [Album] {
        guard await auth.isAuthenticated else { throw PhotoProviderError.notAuthenticated }
        let catalog = try await api.fetchCatalog()
        let lrAlbums = try await api.fetchAlbums(catalogID: catalog.id)
        return lrAlbums.map { lrAlbum in
            Album(
                id: "\(catalog.id)/\(lrAlbum.id)",
                title: lrAlbum.name,
                source: .lightroom,
                estimatedCount: nil
            )
        }
    }

    // MARK: - 사진

    func fetchPhotos(in selection: AlbumSelection) async throws -> [FramePhoto] {
        guard await auth.isAuthenticated else { throw PhotoProviderError.notAuthenticated }
        let catalogID = selection.catalogID ?? (try await api.fetchCatalog().id)
        let assets = try await api.fetchAssets(catalogID: catalogID, albumID: selection.albumID)

        var photos: [FramePhoto] = []
        photos.reserveCapacity(assets.count)
        var newMap: [String: String] = [:]

        for asset in assets {
            let photo = FramePhoto(
                id: asset.id,
                source: .lightroom,
                creationDate: asset.captureDate,
                aspectRatio: asset.aspectRatio
            )
            photos.append(photo)
            newMap[asset.id] = catalogID
        }

        mapLock.lock()
        for (k, v) in newMap { assetCatalogMap[k] = v }
        mapLock.unlock()

        return photos
    }

    // MARK: - 이미지 로드

    func loadImage(for photo: FramePhoto, targetSize: CGSize) async throws -> UIImage {
        mapLock.lock()
        let catalogID = assetCatalogMap[photo.id]
        mapLock.unlock()

        guard let catalogID else {
            throw PhotoProviderError.imageUnavailable
        }
        return try await api.downloadImage(catalogID: catalogID, assetID: photo.id, targetSize: targetSize)
    }
}
