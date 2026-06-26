import Foundation
import UIKit

/// 액자에 표시될 사진을 추상화한 모델. 출처(iOS 사진 / Lightroom)에 관계없이 동일하게 다룬다.
struct FramePhoto: Identifiable, Hashable {
    let id: String
    let source: PhotoSourceKind
    /// 사진 캡처(또는 생성) 시각. 정렬에 사용.
    let creationDate: Date?
    /// 원본 종횡비 (width / height). 알 수 없으면 nil.
    let aspectRatio: CGFloat?

    static func == (lhs: FramePhoto, rhs: FramePhoto) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// 사진 출처 종류.
enum PhotoSourceKind: String, Codable, Hashable {
    case photoLibrary
    case lightroom
    case folder

    var displayName: String {
        switch self {
        case .photoLibrary: return "iOS 사진"
        case .lightroom: return "Lightroom"
        case .folder: return "폴더"
        }
    }

    var systemImage: String {
        switch self {
        case .photoLibrary: return "photo.on.rectangle"
        case .lightroom: return "camera.filters"
        case .folder: return "folder.fill"
        }
    }
}
