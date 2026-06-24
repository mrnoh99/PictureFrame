import SwiftUI

/// 슬라이드쇼에서 사진이 바뀔 때 적용되는 전환 효과.
enum SlideTransition: String, CaseIterable, Codable, Identifiable {
    /// 부드러운 페이드(크로스페이드).
    case crossfade
    /// 옆으로 밀어내기.
    case slide
    /// 확대되며 나타나기.
    case zoom
    /// 아래에서 위로 밀어올리기.
    case pushUp
    /// 여러 효과를 순서대로 번갈아 사용.
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .crossfade: return "크로스페이드"
        case .slide:     return "슬라이드"
        case .zoom:      return "줌"
        case .pushUp:    return "밀어올리기"
        case .mixed:     return "혼합"
        }
    }

    /// 단일 효과 목록(혼합 모드에서 순환에 사용).
    private static let cycle: [SlideTransition] = [.crossfade, .slide, .zoom, .pushUp]

    /// 인덱스에 따라 실제 적용할 SwiftUI 전환을 반환한다.
    /// - Parameter index: 현재 사진 순번(혼합 모드에서 순서대로 효과를 바꾸는 데 사용).
    func swiftUITransition(index: Int) -> AnyTransition {
        switch self {
        case .crossfade:
            return .opacity
        case .slide:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .zoom:
            return .scale(scale: 1.18).combined(with: .opacity)
        case .pushUp:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .mixed:
            let effect = Self.cycle[((index % Self.cycle.count) + Self.cycle.count) % Self.cycle.count]
            return effect.swiftUITransition(index: index)
        }
    }
}
