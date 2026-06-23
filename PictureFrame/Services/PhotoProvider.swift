import Foundation
import UIKit

/// 사진 출처(iOS 사진, Lightroom)가 공통으로 구현하는 인터페이스.
protocol PhotoProvider: AnyObject {
    var kind: PhotoSourceKind { get }

    /// 사용 가능한 앨범 목록을 가져온다.
    func fetchAlbums() async throws -> [Album]

    /// 주어진 앨범에 속한 사진들의 메타데이터를 가져온다.
    /// - Parameter selection: 카탈로그/앨범 식별 정보.
    func fetchPhotos(in selection: AlbumSelection) async throws -> [FramePhoto]

    /// 특정 사진의 이미지를 대상 크기에 맞춰 로드한다.
    func loadImage(for photo: FramePhoto, targetSize: CGSize) async throws -> UIImage
}

enum PhotoProviderError: LocalizedError {
    case notAuthorized
    case notConfigured
    case notAuthenticated
    case albumNotFound
    case imageUnavailable
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "사진 보관함 접근 권한이 없습니다. 설정에서 권한을 허용해 주세요."
        case .notConfigured: return "Lightroom 자격 증명(Client ID)이 설정되지 않았습니다."
        case .notAuthenticated: return "Lightroom 로그인이 필요합니다."
        case .albumNotFound: return "앨범을 찾을 수 없습니다."
        case .imageUnavailable: return "이미지를 불러올 수 없습니다."
        case .server(let message): return "서버 오류: \(message)"
        }
    }
}
