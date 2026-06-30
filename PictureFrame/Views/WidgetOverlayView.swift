import SwiftUI

/// 액자 위에 선택적으로 표시되는 시계/날짜 오버레이.
/// 설정(showClock)에 따라 표시 여부가 결정된다.
struct WidgetOverlayView: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        if settings.showClock {
            VStack(alignment: .leading, spacing: 6) {
                clock
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .padding(28)
        }
    }

    private var clock: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(context.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
