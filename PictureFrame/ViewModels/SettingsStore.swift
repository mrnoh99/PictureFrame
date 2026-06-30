import Foundation
import Combine

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

    /// 폴더 사진 소스의 보안 스코프 북마크 (앨범ID → 북마크 데이터).
    @Published var folderBookmarks: [String: Data] {
        didSet { save(folderBookmarks, key: "folderBookmarks") }
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

    /// Ken Burns 효과 강도 (0.0 ~ 1.0). 0이면 정지, 1이면 최대 팬/줌.
    @Published var kenBurnsIntensity: Double {
        didSet { UserDefaults.standard.set(kenBurnsIntensity, forKey: "kenBurnsIntensity") }
    }

    /// 사진 전환 효과.
    @Published var slideTransition: SlideTransition {
        didSet { UserDefaults.standard.set(slideTransition.rawValue, forKey: "slideTransition") }
    }

    /// "랜덤 선택" 모드에서 무작위로 적용할 효과 목록(최대 5개).
    @Published var selectedTransitions: [SlideTransition] {
        didSet { save(selectedTransitions.map(\.rawValue), key: "selectedTransitions") }
    }

    // MARK: - 장수 설정 (한 화면 사진 수 범위)

    /// 한 화면 사진 수의 최소값 (1~9). 최소=최대면 고정, 다르면 범위 내 무작위.
    @Published var collageRangeMin: Int {
        didSet { UserDefaults.standard.set(collageRangeMin, forKey: "collageRangeMin") }
    }

    /// 한 화면 사진 수의 최대값 (1~9).
    @Published var collageRangeMax: Int {
        didSet { UserDefaults.standard.set(collageRangeMax, forKey: "collageRangeMax") }
    }

    /// 사진 채움 방식(블러 배경 / 비율 맞춤). 한 장씩·콜라주 모두에 적용.
    @Published var slideshowFitStyle: CollageFitStyle {
        didSet { UserDefaults.standard.set(slideshowFitStyle.rawValue, forKey: "slideshowFitStyle") }
    }

    /// 항상 한 장씩(단일) 재생인지 여부(범위가 1~1로 고정). 그 외에는 콜라주 형태로 재생.
    var isSinglePhotoShow: Bool {
        min(collageRangeMin, collageRangeMax) == 1 && max(collageRangeMin, collageRangeMax) == 1
    }

    /// 주어진 장면(scene)에 사용할 한 화면 사진 수.
    /// 최소==최대면 고정, 다르면 범위 안에서 장면마다 결정적으로 달라진다.
    /// (결정적이어야 같은 장면에서 batch/advance/template 가 항상 일치한다.)
    func collagePhotoCount(forScene scene: Int) -> Int {
        let lo = max(1, min(collageRangeMin, collageRangeMax))
        let hi = max(collageRangeMin, collageRangeMax)
        let span = hi - lo + 1
        guard span > 1 else { return lo }
        // 장면 인덱스 기반 의사난수(해시) → 같은 장면이면 항상 같은 값.
        var x = UInt64(bitPattern: Int64(scene &+ 1))
        x = (x &* 0x9E3779B97F4A7C15) ^ (x >> 29)
        return lo + Int(x % UInt64(span))
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

    /// 개별로 추가한 음악 파일명 목록 (앱 Documents/Music 디렉터리 기준, 최대 10개).
    @Published var musicTracks: [String] {
        didSet { save(musicTracks, key: "musicTracks") }
    }

    /// 등록한 폴더에서 가져온 음악 파일명 목록 (앱 Documents/Music 기준).
    @Published var musicFolderTracks: [String] {
        didSet { save(musicFolderTracks, key: "musicFolderTracks") }
    }

    /// 등록한 음악 폴더 이름(표시용). 없으면 nil.
    @Published var musicFolderName: String? {
        didSet { UserDefaults.standard.set(musicFolderName, forKey: "musicFolderName") }
    }

    /// 개별 음악으로 등록 가능한 최대 곡 수.
    static let maxIndividualTracks = 10

    // MARK: - 오버레이(위젯) 설정

    /// 시계/날짜 오버레이 표시 여부.
    @Published var showClock: Bool {
        didSet { UserDefaults.standard.set(showClock, forKey: "showClock") }
    }

    /// 날씨 오버레이 표시 여부.
    @Published var showWeather: Bool {
        didSet { UserDefaults.standard.set(showWeather, forKey: "showWeather") }
    }

    /// 설정 버튼을 항상 표시할지(true) 터치 시만 표시할지(false).
    @Published var alwaysShowControls: Bool {
        didSet { UserDefaults.standard.set(alwaysShowControls, forKey: "alwaysShowControls") }
    }

    /// UI 표시 언어 ("ko" = 한국어, "en" = English).
    @Published var appLanguage: String {
        didSet { UserDefaults.standard.set(appLanguage, forKey: "appLanguage") }
    }

    /// 음악 파일이 저장되는 디렉터리 (Documents/Music).
    static let musicDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// 재생 가능한 음악 파일 URL 목록(개별 + 폴더).
    var musicURLs: [URL] {
        (musicTracks + musicFolderTracks).map { Self.musicDirectory.appendingPathComponent($0) }
    }

    /// 등록된 음악이 하나라도 있는지.
    var hasAnyMusic: Bool {
        !musicTracks.isEmpty || !musicFolderTracks.isEmpty
    }

    // MARK: - 초기화

    init() {
        let defaults = UserDefaults.standard
        selectedAlbums = Self.load(key: "selectedAlbums") ?? []
        folderBookmarks = Self.load(key: "folderBookmarks") ?? [:]
        displayMode = DisplayMode(rawValue: defaults.string(forKey: "displayMode") ?? "") ?? .slideshow
        slideInterval = defaults.double(forKey: "slideInterval").nonZero ?? AppConfig.defaultSlideInterval
        kenBurnsEnabled = defaults.object(forKey: "kenBurnsEnabled") as? Bool ?? true
        kenBurnsIntensity = defaults.object(forKey: "kenBurnsIntensity") as? Double ?? 1.0
        slideTransition = SlideTransition(rawValue: defaults.string(forKey: "slideTransition") ?? "") ?? .crossfade
        let savedTransitions: [String] = Self.load(key: "selectedTransitions") ?? []
        let restored = savedTransitions.compactMap { SlideTransition(rawValue: $0) }
        selectedTransitions = restored.isEmpty ? [.crossfade, .slide, .zoom] : restored
        collageRangeMin = defaults.integer(forKey: "collageRangeMin").nonZero ?? 1
        collageRangeMax = defaults.integer(forKey: "collageRangeMax").nonZero ?? 4
        slideshowFitStyle = CollageFitStyle(rawValue: defaults.string(forKey: "slideshowFitStyle") ?? "") ?? .blurFill
        musicEnabled = defaults.object(forKey: "musicEnabled") as? Bool ?? false
        musicVolume = defaults.object(forKey: "musicVolume") as? Double ?? 0.6
        musicTracks = Self.load(key: "musicTracks") ?? []
        musicFolderTracks = Self.load(key: "musicFolderTracks") ?? []
        musicFolderName = defaults.string(forKey: "musicFolderName")
        showClock = defaults.object(forKey: "showClock") as? Bool ?? false
        showWeather = defaults.object(forKey: "showWeather") as? Bool ?? false
        alwaysShowControls = defaults.object(forKey: "alwaysShowControls") as? Bool ?? true
        appLanguage = defaults.string(forKey: "appLanguage") ?? "ko"
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
        if selection.source == .folder {
            folderBookmarks[selection.albumID] = nil
        }
    }

    /// 폴더를 사진 소스로 등록한다. 보안 스코프 북마크를 저장하고 앨범으로 추가.
    func addFolderAlbum(url: URL) throws {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let albumID = UUID().uuidString
        folderBookmarks[albumID] = bookmark
        addAlbum(AlbumSelection(source: .folder, albumID: albumID, title: url.lastPathComponent))
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
