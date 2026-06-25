import SwiftUI

/// 슬라이드쇼에서 사진이 바뀔 때 적용되는 전환 효과.
enum SlideTransition: String, CaseIterable, Codable, Identifiable {
    /// 부드러운 페이드(크로스페이드).
    case crossfade
    /// 옆으로 밀어내기.
    case slide
    /// 시스템 푸시(옆에서 밀고 들어오기).
    case push
    /// 확대되며 나타나기.
    case zoom
    /// 축소되며 나타나기.
    case zoomOut
    /// 아래에서 위로 밀어올리기.
    case pushUp
    /// 위에서 아래로 내리기.
    case pushDown
    /// 블러로 바뀌기.
    case blur
    /// 책장처럼 넘기기(3D 플립).
    case flip
    /// 여러 효과를 순서대로 번갈아 사용.
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .crossfade: return "크로스페이드"
        case .slide:     return "슬라이드"
        case .push:      return "푸시"
        case .zoom:      return "줌 인"
        case .zoomOut:   return "줌 아웃"
        case .pushUp:    return "밀어올리기"
        case .pushDown:  return "내리기"
        case .blur:      return "블러"
        case .flip:      return "플립"
        case .mixed:     return "혼합"
        }
    }

    /// 단일 효과 목록(혼합 모드에서 순환에 사용).
    private static let cycle: [SlideTransition] = [
        .crossfade, .slide, .push, .zoom, .zoomOut, .pushUp, .pushDown, .blur, .flip
    ]

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
        case .push:
            return .push(from: .trailing)
        case .zoom:
            return .scale(scale: 1.25).combined(with: .opacity)
        case .zoomOut:
            return .scale(scale: 0.8).combined(with: .opacity)
        case .pushUp:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .pushDown:
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        case .blur:
            return .blurReplace
        case .flip:
            return .flip3D
        case .mixed:
            let effect = Self.cycle[((index % Self.cycle.count) + Self.cycle.count) % Self.cycle.count]
            return effect.swiftUITransition(index: index)
        }
    }
}

// MARK: - 3D 플립 전환

extension AnyTransition {
    /// 책장을 넘기듯 Y축으로 회전하며 바뀌는 3D 플립 전환.
    static var flip3D: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: FlipModifier(angle: 90),
                identity: FlipModifier(angle: 0)
            ),
            removal: .modifier(
                active: FlipModifier(angle: -90),
                identity: FlipModifier(angle: 0)
            )
        )
    }
}

/// Y축 3D 회전 + 페이드를 적용하는 전환용 모디파이어.
private struct FlipModifier: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .opacity(angle == 0 ? 1 : 0)
    }
}
