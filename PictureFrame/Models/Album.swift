import Foundation

/// 앨범(사진 컬렉션) 추상화. iOS 사진 앨범과 Lightroom 앨범 모두를 표현한다.
struct Album: Identifiable, Hashable {
    let id: String
    let title: String
    let source: PhotoSourceKind
    /// 사진 개수 (알 수 없으면 nil).
    let estimatedCount: Int?
}

/// 사용자가 선택해 영구 저장하는 앨범 참조.
struct AlbumSelection: Codable, Hashable, Identifiable {
    var id: String { "\(source.rawValue):\(albumID)" }
    let source: PhotoSourceKind
    let albumID: String
    let title: String
    /// Lightroom 앨범의 경우 카탈로그 ID 가 필요하다.
    var catalogID: String?
}
