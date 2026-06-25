import Foundation

/// 액자가 사진을 보여주는 방식.
enum DisplayMode: String, CaseIterable, Codable, Identifiable {
    /// 슬라이드 쇼. 장수에 따라 한 장씩(1장) 또는 콜라주(2장 이상)로 재생.
    case slideshow
    /// (구) 콜라주 — 현재는 슬라이드쇼에 통합됨. 과거 설정 호환용으로만 유지.
    case collage
    /// 격자 갤러리 형태로 스크롤.
    case grid

    var id: String { rawValue }

    /// 표시 방식 선택 목록(콜라주는 슬라이드쇼의 장수로 통합되어 별도 노출하지 않음).
    static var selectableCases: [DisplayMode] { [.slideshow, .grid] }

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
