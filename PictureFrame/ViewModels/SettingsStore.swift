import Foundation
import Combine

/// 콜라주 한 화면의 사진 수를 정하는 방식.
enum CollageCountMode: String, CaseIterable, Codable, Identifiable {
    /// 항상 동일한 장수.
    case fixed
    /// 지정한 범위 안에서 장면마다 무작위.
    case random

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fixed:  return "고정"
        case .random: return "범위 내 무작위"
        }
    }
}

/// 콜라주에서 각 사진을 셀(모양)에 채우는 방식.
enum CollageFitStyle: String, CaseIterable, Codable, Identifiable {
    /// 템플릿 격자 배치 + 사진 전체를 보이게 하고 남는 여백은 블러 배경으로 채움.
    case blurFill
    /// 사진 비율에 맞춰 셀 모양을 동적으로 잡아 여백 없이 배치(잘림·여백 없음).
    case aspect

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .blurFill: return "블러 배경"
        case .aspect:   return "비율 맞춤"
        }
    }
}

/// 사용자 설정을 UserDefaults 에 영속 저장하고 UI 에 바인딩한다.
final class SettingsStore: ObservableObject {
    // MARK: - 선택된 앨범

    @Published var selectedAlbums: [AlbumSelection] {
        didSet { save(selectedAlbums, key: "selectedAlbums") }
    }

    // MARK: - 표시 모드

    @Published var displayMode: DisplayMode {
        didSet { UserDefaults.standard.set(displayMode.rawValue, forKey: "displayMode") }
    }

    // MARK: - 슬라이드쇼 설정

    @Published var slideInterval: TimeInterval {
        didSet { UserDefaults.standard.set(slideInterval, forKey: "slideInterval") }
    }

    /// Ken Burns 효과 사용 여부.
    @Published var kenBurnsEnabled: Bool {
        didSet { UserDefaults.standard.set(kenBurnsEnabled, forKey: "kenBurnsEnabled") }
    }

    /// 사진 전환 효과.
    @Published var slideTransition: SlideTransition {
        didSet { UserDefaults.standard.set(slideTransition.rawValue, forKey: "slideTransition") }
    }

    // MARK: - 콜라주 설정

    /// 콜라주 장수 결정 방식(고정/범위 무작위).
    @Published var collageCountMode: CollageCountMode {
        didSet { UserDefaults.standard.set(collageCountMode.rawValue, forKey: "collageCountMode") }
    }

    /// 콜라주 한 화면에 표시할 사진 수 (고정 모드, 2~9).
    @Published var collageCount: Int {
        didSet { UserDefaults.standard.set(collageCount, forKey: "collageCount") }
    }

    /// 무작위 모드의 최소 장수 (2~9).
    @Published var collageRangeMin: Int {
        didSet { UserDefaults.standard.set(collageRangeMin, forKey: "collageRangeMin") }
    }

    /// 무작위 모드의 최대 장수 (2~9).
    @Published var collageRangeMax: Int {
        didSet { UserDefaults.standard.set(collageRangeMax, forKey: "collageRangeMax") }
    }

    /// 사진 채움 방식(블러 배경 / 비율 맞춤). 한 장씩·콜라주 모두에 적용.
    @Published var slideshowFitStyle: CollageFitStyle {
        didSet { UserDefaults.standard.set(slideshowFitStyle.rawValue, forKey: "slideshowFitStyle") }
    }

    /// 한 장씩 슬라이드쇼인지 여부(장수 고정 = 1장). 그 외에는 콜라주 형태로 재생.
    var isSinglePhotoShow: Bool {
        collageCountMode == .fixed && collageCount == 1
    }

    /// 주어진 장면(scene)에 사용할 콜라주 사진 수.
    /// 고정 모드면 항상 동일하고, 무작위 모드면 장면마다 범위 안에서 결정적으로 달라진다.
    /// (결정적이어야 같은 장면에서 batch/advance/template 가 항상 일치한다.)
    func collagePhotoCount(forScene scene: Int) -> Int {
        switch collageCountMode {
        case .fixed:
            return collageCount
        case .random:
            let lo = max(1, min(collageRangeMin, collageRangeMax))
            let hi = max(collageRangeMin, collageRangeMax)
            let span = hi - lo + 1
            guard span > 1 else { return lo }
            // 장면 인덱스 기반 의사난수(해시) → 같은 장면이면 항상 같은 값.
            var x = UInt64(bitPattern: Int64(scene &+ 1))
            x = (x &* 0x9E3779B97F4A7C15) ^ (x >> 29)
            return lo + Int(x % UInt64(span))
        }
    }

    // MARK: - 배경음악 설정

    /// 배경음악 사용 여부.
    @Published var musicEnabled: Bool {
        didSet { UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled") }
    }

    /// 배경음악 볼륨 (0.0 ~ 1.0).
    @Published var musicVolume: Double {
        didSet { UserDefaults.standard.set(musicVolume, forKey: "musicVolume") }
    }

    /// 가져온 음악 파일명 목록 (앱 Documents/Music 디렉터리 기준).
    @Published var musicTracks: [String] {
        didSet { save(musicTracks, key: "musicTracks") }
    }

    // MARK: - 오버레이(위젯) 설정

    /// 시계/날짜 오버레이 표시 여부.
    @Published var showClock: Bool {
        didSet { UserDefaults.standard.set(showClock, forKey: "showClock") }
    }

    /// 날씨 오버레이 표시 여부.
    @Published var showWeather: Bool {
        didSet { UserDefaults.standard.set(showWeather, forKey: "showWeather") }
    }

    /// 음악 파일이 저장되는 디렉터리 (Documents/Music).
    static let musicDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// 재생 가능한 음악 파일 URL 목록.
    var musicURLs: [URL] {
        musicTracks.map { Self.musicDirectory.appendingPathComponent($0) }
    }

    // MARK: - 초기화

    init() {
        let defaults = UserDefaults.standard
        selectedAlbums = Self.load(key: "selectedAlbums") ?? []
        displayMode = DisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "") ?? .slideshow
        slideInterval = defaults.double(forKey: "slideInterval").nonZero ?? AppConfig.defaultSlideInterval
        kenBurnsEnabled = defaults.object(forKey: "kenBurnsEnabled") as? Bool ?? true
        slideTransition = SlideTransition(rawValue: defaults.string(forKey: "slideTransition") ?? "") ?? .crossfade
        collageCountMode = CollageCountMode(rawValue: defaults.string(forKey: "collageCountMode") ?? "") ?? .fixed
        collageCount = defaults.integer(forKey: "collageCount").nonZero ?? 4
        collageRangeMin = defaults.integer(forKey: "collageRangeMin").nonZero ?? 3
        collageRangeMax = defaults.integer(forKey: "collageRangeMax").nonZero ?? 6
        slideshowFitStyle = CollageFitStyle(rawValue: defaults.string(forKey: "slideshowFitStyle") ?? "") ?? .blurFill
        musicEnabled = defaults.object(forKey: "musicEnabled") as? Bool ?? false
        musicVolume = defaults.object(forKey: "musicVolume") as? Double ?? 0.6
        musicTracks = Self.load(key: "musicTracks") ?? []
        showClock = defaults.object(forKey: "showClock") as? Bool ?? false
        showWeather = defaults.object(forKey: "showWeather") as? Bool ?? false
    }

    // MARK: - 헬퍼

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func addAlbum(_ selection: AlbumSelection) {
        guard !selectedAlbums.contains(selection) else { return }
        selectedAlbums.append(selection)
    }

    func removeAlbum(_ selection: AlbumSelection) {
        selectedAlbums.removeAll { $0 == selection }
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
