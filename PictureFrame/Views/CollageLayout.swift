import CoreGraphics

/// 콜라주 한 장면의 배치 템플릿.
/// 각 사진의 위치를 단위 좌표(0...1)의 사각형으로 정의한다.
/// 그리드에 얽매이지 않는 창의적 배치를 표현할 수 있다.
struct CollageTemplate {
    /// 단위 좌표계(0...1)에서의 각 셀 사각형. 개수 = 사진 수.
    let cells: [CGRect]

    var count: Int { cells.count }
}

/// 사진 수별로 여러 창의적 레이아웃 템플릿을 제공한다.
/// 같은 장수라도 장면마다 다른 배치가 나오도록 여러 변형을 담는다.
enum CollageLayouts {

    /// 주어진 사진 수에 대한 템플릿 변형 목록.
    static func templates(for count: Int) -> [CollageTemplate] {
        switch count {
        case 1:  return [CollageTemplate(cells: [r(0, 0, 1, 1)])]
        case 2:  return two
        case 3:  return three
        case 4:  return four
        case 5:  return five
        case 6:  return six
        default: return [grid(count)]
        }
    }

    /// 사진 수와 장면 인덱스를 받아 순환하며 변형을 고른다(창의적 다양성).
    static func template(count: Int, variant: Int) -> CollageTemplate {
        let list = templates(for: count)
        guard !list.isEmpty else { return grid(count) }
        let idx = ((variant % list.count) + list.count) % list.count
        return list[idx]
    }

    // MARK: - 헬퍼

    private static func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - 2장

    private static let two: [CollageTemplate] = [
        // 좌우 분할
        CollageTemplate(cells: [r(0, 0, 0.5, 1), r(0.5, 0, 0.5, 1)]),
        // 상하 분할
        CollageTemplate(cells: [r(0, 0, 1, 0.5), r(0, 0.5, 1, 0.5)]),
        // 큰 사진 + 작은 사진(비대칭 황금비)
        CollageTemplate(cells: [r(0, 0, 0.62, 1), r(0.62, 0, 0.38, 1)]),
        // 상단 와이드 + 하단 좁게
        CollageTemplate(cells: [r(0, 0, 1, 0.62), r(0, 0.62, 1, 0.38)])
    ]

    // MARK: - 3장

    private static let three: [CollageTemplate] = [
        // 좌측 대형 + 우측 2단
        CollageTemplate(cells: [r(0, 0, 0.6, 1), r(0.6, 0, 0.4, 0.5), r(0.6, 0.5, 0.4, 0.5)]),
        // 우측 대형 + 좌측 2단(거울)
        CollageTemplate(cells: [r(0, 0, 0.4, 0.5), r(0, 0.5, 0.4, 0.5), r(0.4, 0, 0.6, 1)]),
        // 상단 와이드 + 하단 2분할
        CollageTemplate(cells: [r(0, 0, 1, 0.55), r(0, 0.55, 0.5, 0.45), r(0.5, 0.55, 0.5, 0.45)]),
        // 3열 세로 스트립
        CollageTemplate(cells: [r(0, 0, 0.34, 1), r(0.34, 0, 0.33, 1), r(0.67, 0, 0.33, 1)]),
        // 중앙 대형 + 양옆(세로 파노라마)
        CollageTemplate(cells: [r(0, 0, 0.25, 1), r(0.25, 0, 0.5, 1), r(0.75, 0, 0.25, 1)]),
        // 3단 가로 스트립
        CollageTemplate(cells: [r(0, 0, 1, 0.34), r(0, 0.34, 1, 0.33), r(0, 0.67, 1, 0.33)])
    ]

    // MARK: - 4장

    private static let four: [CollageTemplate] = [
        // 2x2 균등
        CollageTemplate(cells: [r(0, 0, 0.5, 0.5), r(0.5, 0, 0.5, 0.5), r(0, 0.5, 0.5, 0.5), r(0.5, 0.5, 0.5, 0.5)]),
        // 좌측 대형 + 우측 3단
        CollageTemplate(cells: [r(0, 0, 0.55, 1), r(0.55, 0, 0.45, 0.34), r(0.55, 0.34, 0.45, 0.33), r(0.55, 0.67, 0.45, 0.33)]),
        // 상단 와이드 1 + 하단 3분할
        CollageTemplate(cells: [r(0, 0, 1, 0.5), r(0, 0.5, 0.34, 0.5), r(0.34, 0.5, 0.33, 0.5), r(0.67, 0.5, 0.33, 0.5)]),
        // 풍차(pinwheel) 배치
        CollageTemplate(cells: [r(0, 0, 0.6, 0.5), r(0.6, 0, 0.4, 0.6), r(0, 0.5, 0.4, 0.5), r(0.4, 0.6, 0.6, 0.4)]),
        // 4열 세로 스트립
        CollageTemplate(cells: [r(0, 0, 0.25, 1), r(0.25, 0, 0.25, 1), r(0.5, 0, 0.25, 1), r(0.75, 0, 0.25, 1)]),
        // 좌측 세로 2단 + 우측 대형(중앙 강조 변형)
        CollageTemplate(cells: [r(0, 0, 0.32, 0.5), r(0, 0.5, 0.32, 0.5), r(0.32, 0, 0.68, 0.6), r(0.32, 0.6, 0.68, 0.4)])
    ]

    // MARK: - 5장

    private static let five: [CollageTemplate] = [
        // 좌측 대형 + 우측 2x2
        CollageTemplate(cells: [
            r(0, 0, 0.5, 1),
            r(0.5, 0, 0.25, 0.5), r(0.75, 0, 0.25, 0.5),
            r(0.5, 0.5, 0.25, 0.5), r(0.75, 0.5, 0.25, 0.5)
        ]),
        // 상단 2 + 하단 3
        CollageTemplate(cells: [
            r(0, 0, 0.5, 0.5), r(0.5, 0, 0.5, 0.5),
            r(0, 0.5, 0.34, 0.5), r(0.34, 0.5, 0.33, 0.5), r(0.67, 0.5, 0.33, 0.5)
        ]),
        // 중앙 대형 + 모서리 4
        CollageTemplate(cells: [
            r(0.25, 0.2, 0.5, 0.6),
            r(0, 0, 0.25, 0.5), r(0.75, 0, 0.25, 0.5),
            r(0, 0.5, 0.25, 0.5), r(0.75, 0.5, 0.25, 0.5)
        ]),
        // 상단 3 + 하단 2(와이드)
        CollageTemplate(cells: [
            r(0, 0, 0.34, 0.5), r(0.34, 0, 0.33, 0.5), r(0.67, 0, 0.33, 0.5),
            r(0, 0.5, 0.5, 0.5), r(0.5, 0.5, 0.5, 0.5)
        ])
    ]

    // MARK: - 6장

    private static let six: [CollageTemplate] = [
        // 3x2 균등
        CollageTemplate(cells: [
            r(0, 0, 0.34, 0.5), r(0.34, 0, 0.33, 0.5), r(0.67, 0, 0.33, 0.5),
            r(0, 0.5, 0.34, 0.5), r(0.34, 0.5, 0.33, 0.5), r(0.67, 0.5, 0.33, 0.5)
        ]),
        // 좌측 대형 + 우측 5분할(2단 + 3단 혼합)
        CollageTemplate(cells: [
            r(0, 0, 0.5, 1),
            r(0.5, 0, 0.5, 0.34), r(0.5, 0.34, 0.25, 0.33), r(0.75, 0.34, 0.25, 0.33),
            r(0.5, 0.67, 0.25, 0.33), r(0.75, 0.67, 0.25, 0.33)
        ]),
        // 상단 와이드 + 하단 와이드, 중앙 띠 3분할
        CollageTemplate(cells: [
            r(0, 0, 0.5, 0.5), r(0.5, 0, 0.5, 0.5),
            r(0, 0.5, 0.25, 0.5), r(0.25, 0.5, 0.25, 0.5), r(0.5, 0.5, 0.25, 0.5), r(0.75, 0.5, 0.25, 0.5)
        ])
    ]

    // MARK: - 일반 그리드 (폴백)

    static func grid(_ count: Int) -> CollageTemplate {
        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))
        let cw = 1.0 / CGFloat(cols)
        let ch = 1.0 / CGFloat(rows)
        var cells: [CGRect] = []
        for i in 0..<count {
            let col = i % cols
            let row = i / cols
            cells.append(CGRect(x: CGFloat(col) * cw, y: CGFloat(row) * ch, width: cw, height: ch))
        }
        return CollageTemplate(cells: cells)
    }
}
