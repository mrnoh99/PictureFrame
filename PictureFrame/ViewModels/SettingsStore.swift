import Foundation
import Combine

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

    /// 콜라주 한 화면에 표시할 사진 수 (2~9).
    @Published var collageCount: Int {
        didSet { UserDefaults.standard.set(collageCount, forKey: "collageCount") }
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
        collageCount = defaults.integer(forKey: "collageCount").nonZero ?? 4
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
