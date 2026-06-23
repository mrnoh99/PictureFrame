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

    // MARK: - 콜라주 설정

    /// 콜라주 한 화면에 표시할 사진 수 (2~9).
    @Published var collageCount: Int {
        didSet { UserDefaults.standard.set(collageCount, forKey: "collageCount") }
    }

    // MARK: - 초기화

    init() {
        let defaults = UserDefaults.standard
        selectedAlbums = Self.load(key: "selectedAlbums") ?? []
        displayMode = DisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "") ?? .slideshow
        slideInterval = defaults.double(forKey: "slideInterval").nonZero ?? AppConfig.defaultSlideInterval
        kenBurnsEnabled = defaults.object(forKey: "kenBurnsEnabled") as? Bool ?? true
        collageCount = defaults.integer(forKey: "collageCount").nonZero ?? 4
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
