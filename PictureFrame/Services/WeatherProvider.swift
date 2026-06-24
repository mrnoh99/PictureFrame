import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// 현재 위치의 날씨를 가져온다(WeatherKit + CoreLocation).
/// WeatherKit capability 가 설정되지 않았거나 권한이 없으면 조용히 비활성화된다.
@MainActor
final class WeatherProvider: NSObject, ObservableObject {
    @Published private(set) var temperatureText: String?
    @Published private(set) var symbolName: String = "cloud.fill"
    @Published private(set) var conditionText: String?

    private let locationManager = CLLocationManager()
    /// 너무 잦은 갱신 방지(최소 갱신 간격, 초).
    private var lastFetch: Date?
    private let minInterval: TimeInterval = 600

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// 날씨 갱신을 시작한다(권한 요청 포함).
    func start() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }

    private func fetchWeather(for location: CLLocation) {
        if let last = lastFetch, Date().timeIntervalSince(last) < minInterval { return }
        lastFetch = Date()

        #if canImport(WeatherKit)
        if #available(iOS 16.0, *) {
            Task {
                do {
                    let weather = try await WeatherKit.WeatherService.shared.weather(for: location)
                    let current = weather.currentWeather
                    let formatter = MeasurementFormatter()
                    formatter.numberFormatter.maximumFractionDigits = 0
                    formatter.unitOptions = .temperatureWithoutUnit
                    temperatureText = formatter.string(from: current.temperature) + "°"
                    symbolName = current.symbolName
                    conditionText = current.condition.description
                } catch {
                    // WeatherKit 미설정/네트워크 실패 → 무시(오버레이에서 날씨 숨김)
                    lastFetch = nil
                }
            }
        }
        #endif
    }
}

extension WeatherProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.fetchWeather(for: location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 위치 실패는 조용히 무시.
    }
}
