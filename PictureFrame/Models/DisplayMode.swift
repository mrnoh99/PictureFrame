import Foundation

/// 액자가 사진을 보여주는 방식.
enum DisplayMode: String, CaseIterable, Codable, Identifiable {
    /// 한 장씩 부드러운 Ken Burns(팬/줌) 효과로 전환.
    case slideshow
    /// 여러 장을 한 화면에 모자이크 콜라주로 배치.
    case collage
    /// 격자 갤러리 형태로 스크롤.
    case grid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .slideshow: return "슬라이드쇼"
        case .collage: return "콜라주"
        case .grid: return "그리드"
        }
    }

    var systemImage: String {
        switch self {
        case .slideshow: return "photo.fill"
        case .collage: return "rectangle.3.group.fill"
        case .grid: return "square.grid.2x2.fill"
        }
    }
}
