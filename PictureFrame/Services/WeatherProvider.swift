import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// 현재 위치의 날씨를 가져온다(WeatherKit + CoreLocation).
/// WeatherKit capability 가 설정되지 않았거나 권한이 없으면 조용히 비활성화된다.
/// 날씨 기능의 현재 사용 가능 상태.
enum WeatherAvailability {
    case idle               // 아직 시작 안 함
    case requesting         // 위치 권한/날씨 요청 중
    case denied             // 위치 권한 거부됨
    case available          // 날씨 데이터 정상
    case unavailable        // WeatherKit 미설정 또는 조회 실패

    var message: String {
        switch self {
        case .idle:        return "날씨를 켜면 현재 위치의 날씨를 표시합니다."
        case .requesting:  return "위치 권한 확인 및 날씨를 불러오는 중입니다…"
        case .denied:      return "위치 권한이 거부되어 날씨를 표시할 수 없습니다. 설정 > 개인정보 보호 > 위치에서 허용해 주세요."
        case .available:   return "날씨 데이터를 사용할 수 있습니다."
        case .unavailable: return "날씨 데이터를 사용할 수 없습니다. WeatherKit 설정(Xcode capability + Apple Developer 등록)이 필요하며, 미설정 시 자동으로 숨겨집니다."
        }
    }

    var isOK: Bool { self == .available }
}

@MainActor
final class WeatherProvider: NSObject, ObservableObject {
    @Published private(set) var temperatureText: String?
    @Published private(set) var symbolName: String = "cloud.fill"
    @Published private(set) var conditionText: String?
    /// 현재 날씨 기능 가용 상태(설정 화면 안내용).
    @Published private(set) var availability: WeatherAvailability = .idle

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
            availability = .requesting
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            availability = .requesting
            locationManager.requestLocation()
        case .denied, .restricted:
            availability = .denied
        @unknown default:
            availability = .unavailable
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
                    availability = .available
                } catch {
                    // WeatherKit 미설정/네트워크 실패 → 무시(오버레이에서 날씨 숨김)
                    lastFetch = nil
                    availability = .unavailable
                }
            }
        } else {
            availability = .unavailable
        }
        #else
        availability = .unavailable
        #endif
    }
}

extension WeatherProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.availability = .denied
            default:
                break
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
