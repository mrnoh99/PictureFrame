import SwiftUI
import UniformTypeIdentifiers

/// 앨범 선택, 표시 모드, 슬라이드쇼·콜라주·배경음악 옵션을 설정하는 화면.
/// iPad 가로 모드에 맞춰 사이드바 + 디테일 형태의 Split View 로 구성.
struct SettingsView: View {
    let photoLib: PhotoLibraryService
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var lightroomAuth: LightroomAuthService
    @EnvironmentObject private var weather: WeatherProvider
    @Environment(\.dismiss) private var dismiss

    @State private var selection: SettingsSection? = .albums
    @State private var showAlbumPicker = false
    @State private var albumSource: PhotoSourceKind = .photoLibrary
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showMusicImporter = false
    @State private var showFolderImporter = false
    @State private var showPhotoFolderImporter = false
    @State private var musicImportError: String?
    @State private var pendingSourceInfo: String?

    enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
        case albums, slideshow, grid, music, overlay, lightroom
        var id: String { rawValue }

        static var sidebarCases: [SettingsSection] { allCases }

        var title: String {
            switch self {
            case .albums:    return "앨범 소스"
            case .slideshow: return "슬라이드쇼"
            case .grid:      return "그리드"
            case .music:     return "배경음악"
            case .overlay:   return "위젯 오버레이"
            case .lightroom: return "Lightroom 계정"
            }
        }

        var titleEn: String {
            switch self {
            case .albums:    return "Album Source"
            case .slideshow: return "Slideshow"
            case .grid:      return "Grid"
            case .music:     return "Music"
            case .overlay:   return "Widgets"
            case .lightroom: return "Lightroom"
            }
        }

        var systemImage: String {
            switch self {
            case .albums:    return "photo.on.rectangle.angled"
            case .slideshow: return "play.rectangle"
            case .grid:      return "square.grid.2x2"
            case .music:     return "music.note"
            case .overlay:   return "clock"
            case .lightroom: return "camera.filters"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                // 언어 선택 — 사이드바 최상단
                Section {
                    Picker("", selection: $settings.appLanguage) {
                        Text("한국어").tag("ko")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                }

                ForEach(SettingsSection.sidebarCases) { section in
                    Label(sectionTitle(section), systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle(t("설정", "Settings"))
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        dismiss()
                    } label: {
                        Label(t("쇼 시작", "Start Show"), systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(settings.selectedAlbums.isEmpty)
                    .padding(.horizontal)

                    Text("Developed by JaiSung NOH MD 2026")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                .padding(.top, 8)
                .background(.bar)
            }
        } detail: {
            NavigationStack {
                detailView(for: selection ?? .albums)
                    .navigationTitle(sectionTitle(selection ?? .albums))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showAlbumPicker) {
            AlbumPickerView(source: albumSource, photoLib: photoLib)
        }
        .onChange(of: selection) { _, newValue in
            switch newValue {
            case .slideshow: settings.displayMode = .slideshow
            case .grid:      settings.displayMode = .grid
            default:         break
            }
        }
    }

    // MARK: - 번역 헬퍼

    private func t(_ ko: String, _ en: String) -> String {
        settings.appLanguage == "en" ? en : ko
    }

    private func sectionTitle(_ section: SettingsSection) -> String {
        settings.appLanguage == "en" ? section.titleEn : section.title
    }

    private func transitionName(_ tr: SlideTransition) -> String {
        guard settings.appLanguage == "en" else { return tr.displayName }
        switch tr {
        case .crossfade:      return "Crossfade"
        case .slide:          return "Slide"
        case .push:           return "Push"
        case .zoom:           return "Zoom In"
        case .zoomOut:        return "Zoom Out"
        case .pushUp:         return "Push Up"
        case .pushDown:       return "Push Down"
        case .blur:           return "Blur"
        case .flip:           return "Flip"
        case .mixed:          return "Mixed"
        case .randomSelected: return "Random Pick"
        }
    }

    private func fitStyleName(_ style: CollageFitStyle) -> String {
        guard settings.appLanguage == "en" else { return style.displayName }
        switch style {
        case .blurFill: return "Blur Background"
        case .aspect:   return "Aspect Fit"
        }
    }

    // MARK: - 디테일 화면 분기

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .albums:    albumsDetail
        case .slideshow: slideshowDetail
        case .grid:      gridDetail
        case .music:     musicDetail
        case .overlay:   overlayDetail
        case .lightroom: lightroomDetail
        }
    }

    // MARK: 위젯 오버레이

    private var overlayDetail: some View {
        Form {
            Section {
                Toggle(t("시계·날짜 표시", "Show Clock & Date"), isOn: $settings.showClock)
            } header: {
                Text(t("시계", "Clock"))
            }

            Section {
                Toggle(t("날씨 표시", "Show Weather"), isOn: $settings.showWeather)
            } header: {
                Text(t("날씨", "Weather"))
            } footer: {
                Text(t("현재 위치의 날씨를 액자 위에 표시합니다.",
                       "Displays current location weather over the frame."))
            }

            if settings.showWeather {
                Section(t("날씨 상태", "Weather Status")) {
                    HStack(spacing: 12) {
                        Image(systemName: weatherStatusIcon)
                            .font(.title3)
                            .foregroundStyle(weatherStatusColor)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(weatherStatusTitle)
                                .font(.subheadline.weight(.medium))
                            Text(weather.availability.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if weather.availability.isOK, let temp = weather.temperatureText {
                        HStack {
                            Image(systemName: weather.symbolName).symbolRenderingMode(.multicolor)
                            Text(t("현재 \(temp)", "Current \(temp)"))
                            if let c = weather.conditionText { Text("· \(c)").foregroundStyle(.secondary) }
                        }
                        .font(.callout)
                    }
                }
            }
        }
        .task(id: settings.showWeather) {
            if settings.showWeather { weather.start() }
        }
    }

    private var weatherStatusIcon: String {
        switch weather.availability {
        case .available: return "checkmark.circle.fill"
        case .denied, .unavailable: return "exclamationmark.triangle.fill"
        default: return "clock.fill"
        }
    }

    private var weatherStatusColor: Color {
        switch weather.availability {
        case .available: return .green
        case .denied, .unavailable: return .orange
        default: return .secondary
        }
    }

    private var weatherStatusTitle: String {
        switch weather.availability {
        case .idle:        return t("대기 중", "Idle")
        case .requesting:  return t("확인 중…", "Checking…")
        case .denied:      return t("위치 권한 없음", "Location Denied")
        case .available:   return t("사용 가능", "Available")
        case .unavailable: return t("사용 불가", "Unavailable")
        }
    }

    // MARK: 앨범 소스

    private var albumsDetail: some View {
        Form {
            Section(t("선택된 앨범", "Selected Albums")) {
                if settings.selectedAlbums.isEmpty {
                    Text(t("아직 앨범을 선택하지 않았습니다", "No albums selected yet"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.selectedAlbums) { sel in
                        HStack {
                            Image(systemName: sel.source.systemImage)
                                .foregroundStyle(.accent)
                            VStack(alignment: .leading) {
                                Text(sel.title).font(.body)
                                Text(sel.source.displayName)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { i in
                            settings.removeAlbum(settings.selectedAlbums[i])
                        }
                    }
                }
            }

            Section(t("앨범 추가", "Add Albums")) {
                Button {
                    albumSource = .photoLibrary
                    showAlbumPicker = true
                } label: {
                    Label(t("iOS 사진 앨범", "iOS Photo Library"), systemImage: "photo.on.rectangle")
                }

                Button {
                    showPhotoFolderImporter = true
                } label: {
                    Label(t("폴더에서 사진 선택", "Select Photo Folder"), systemImage: "folder.badge.plus")
                }

                if AppConfig.Lightroom.partnerApprovalPending {
                    Button {
                        selection = .lightroom
                    } label: {
                        Label(t("Lightroom (승인 대기 중)", "Lightroom (Pending Approval)"),
                              systemImage: "clock.badge.exclamationmark")
                            .foregroundStyle(.orange)
                    }
                } else if AppConfig.Lightroom.isConfigured {
                    Button {
                        albumSource = .lightroom
                        showAlbumPicker = true
                    } label: {
                        Label(t("Lightroom 앨범", "Lightroom Albums"), systemImage: "camera.filters")
                    }
                } else {
                    Button {
                        selection = .lightroom
                    } label: {
                        Label(t("Lightroom 설정 필요", "Lightroom Setup Required"),
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Button {
                    pendingSourceInfo = t(
                        "네이버 MyBox 연동은 준비 중입니다. 네이버 OAuth 앱 등록과 API 승인 후 사용할 수 있습니다.",
                        "Naver MyBox integration is coming soon. Available after OAuth app registration and API approval."
                    )
                } label: {
                    Label(t("네이버 MyBox (준비 중)", "Naver MyBox (Coming Soon)"),
                          systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }

                Button {
                    pendingSourceInfo = t(
                        "구글 포토 연동은 준비 중입니다. Google Photos API OAuth 클라이언트 등록과 승인 후 사용할 수 있습니다.",
                        "Google Photos integration is coming soon. Available after OAuth client registration and approval."
                    )
                } label: {
                    Label(t("구글 포토 (준비 중)", "Google Photos (Coming Soon)"),
                          systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }
        }
        .alert(t("연동 준비 중", "Coming Soon"), isPresented: Binding(
            get: { pendingSourceInfo != nil },
            set: { if !$0 { pendingSourceInfo = nil } }
        )) {
            Button(t("확인", "OK"), role: .cancel) { pendingSourceInfo = nil }
        } message: {
            Text(pendingSourceInfo ?? "")
        }
        .fileImporter(
            isPresented: $showPhotoFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            importPhotoFolder(result)
        }
    }

    private func importPhotoFolder(_ result: Result<[URL], Error>) {
        guard let folder = try? result.get().first else { return }
        do {
            try settings.addFolderAlbum(url: folder)
        } catch {
            pendingSourceInfo = t(
                "폴더를 등록하지 못했습니다: \(error.localizedDescription)",
                "Failed to register folder: \(error.localizedDescription)"
            )
        }
    }

    // MARK: 그리드

    private var gridDetail: some View {
        Form {
            Section {
                Text(t("전체 사진을 격자 갤러리 형태로 한눈에 보여주고 스크롤할 수 있습니다.",
                       "View all photos in a scrollable grid gallery."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(t("그리드", "Grid"))
            }
        }
    }

    // MARK: 장수·채움 공통 섹션

    @ViewBuilder
    private var showCountSections: some View {
        Section {
            let lo = min(settings.collageRangeMin, settings.collageRangeMax)
            let hi = max(settings.collageRangeMin, settings.collageRangeMax)
            HStack {
                Text(t("한 화면 사진 수", "Photos per Scene"))
                Spacer()
                Text(lo == hi
                     ? t("\(lo)장 (고정)", "\(lo) (fixed)")
                     : t("\(lo)~\(hi)장 (무작위)", "\(lo)–\(hi) (random)"))
                    .foregroundStyle(.secondary)
            }
            Stepper(value: $settings.collageRangeMin, in: 1...9) {
                Text(t("최소 \(settings.collageRangeMin)장", "Min \(settings.collageRangeMin)"))
            }
            Stepper(value: $settings.collageRangeMax, in: 1...9) {
                Text(t("최대 \(settings.collageRangeMax)장", "Max \(settings.collageRangeMax)"))
            }
        } header: {
            Text(t("장수", "Count"))
        } footer: {
            Text(t(
                "최소·최대를 같게 하면 고정 장수, 다르게 하면 그 범위 안에서 장면마다 무작위로 정해집니다. 1장이면 한 장씩 슬라이드쇼, 2장 이상이면 콜라주 형태로 재생됩니다.",
                "Equal min/max = fixed count; different = random per scene. 1 photo = slideshow, 2+ = collage."
            ))
        }
    }

    // MARK: 슬라이드쇼

    private var slideshowDetail: some View {
        Form {
            showCountSections

            Section(t("사진 채움 방식", "Photo Fill")) {
                Picker(t("채움 방식", "Fill Style"), selection: $settings.slideshowFitStyle) {
                    ForEach(CollageFitStyle.allCases) { style in
                        Text(fitStyleName(style)).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.slideshowFitStyle == .blurFill
                     ? t("사진 전체를 보여주고, 남는 여백은 블러 배경으로 채웁니다.",
                         "Shows the full photo; remaining space is filled with a blurred background.")
                     : t("사진 전체를 비율 그대로 보여줍니다(남는 부분은 검은 여백).",
                         "Shows the full photo at its aspect ratio (black letterbox)."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text(t("전환 간격", "Interval"))
                    Spacer()
                    Text(t("\(Int(settings.slideInterval))초", "\(Int(settings.slideInterval))s"))
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.slideInterval, in: 2...60, step: 1) {
                    Text(t("전환 간격", "Interval"))
                } minimumValueLabel: {
                    Text(t("2초", "2s")).font(.caption2)
                } maximumValueLabel: {
                    Text(t("60초", "60s")).font(.caption2)
                }
            } header: {
                Text(t("전환 속도", "Transition Speed"))
            } footer: {
                Text(t("사진이 다음 장으로 넘어가는 간격입니다. (2초 ~ 60초)",
                       "Interval between photo transitions. (2s – 60s)"))
            }

            Section(t("전환 효과", "Transition Effect")) {
                Picker(t("전환 효과", "Effect"), selection: $settings.slideTransition) {
                    ForEach(SlideTransition.allCases) { transition in
                        Text(transitionName(transition)).tag(transition)
                    }
                }
                .pickerStyle(.menu)
            }

            if settings.slideTransition == .randomSelected {
                Section {
                    ForEach(SlideTransition.concreteEffects) { effect in
                        let isOn = settings.selectedTransitions.contains(effect)
                        Button {
                            toggleTransition(effect)
                        } label: {
                            HStack {
                                Text(transitionName(effect))
                                Spacer()
                                if isOn {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .disabled(!isOn && settings.selectedTransitions.count >= SlideTransition.maxRandomSelection)
                    }
                } header: {
                    Text(t("적용할 효과 (최대 \(SlideTransition.maxRandomSelection)개)",
                           "Effects to apply (max \(SlideTransition.maxRandomSelection))"))
                } footer: {
                    Text(t("선택한 \(settings.selectedTransitions.count)개 효과 중 무작위로 적용됩니다.",
                           "\(settings.selectedTransitions.count) effect(s) selected; applied randomly."))
                }
            }

            if settings.isSinglePhotoShow {
                Section {
                    Toggle(t("Ken Burns 효과", "Ken Burns Effect"), isOn: $settings.kenBurnsEnabled)

                    if settings.kenBurnsEnabled {
                        HStack {
                            Text(t("강도", "Intensity"))
                            Spacer()
                            Text("\(Int((settings.kenBurnsIntensity * 100).rounded()))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.kenBurnsIntensity, in: 0...1, step: 0.05) {
                            Text(t("강도", "Intensity"))
                        } minimumValueLabel: {
                            Text("0%").font(.caption2)
                        } maximumValueLabel: {
                            Text("100%").font(.caption2)
                        }
                    }
                } header: {
                    Text(t("효과", "Effect"))
                } footer: {
                    Text(t("강도가 높을수록 팬/줌 움직임이 커집니다. 0%면 움직임 없이 고정됩니다.",
                           "Higher intensity means more pan/zoom movement. 0% = no movement."))
                }
            }
        }
    }

    private func toggleTransition(_ effect: SlideTransition) {
        if let idx = settings.selectedTransitions.firstIndex(of: effect) {
            settings.selectedTransitions.remove(at: idx)
        } else if settings.selectedTransitions.count < SlideTransition.maxRandomSelection {
            settings.selectedTransitions.append(effect)
        }
    }

    // MARK: 배경음악

    private var musicDetail: some View {
        Form {
            Section {
                Toggle(t("배경음악 사용", "Enable Background Music"), isOn: $settings.musicEnabled)
            } footer: {
                Text(t("슬라이드쇼·콜라주 재생 중 음악이 반복 재생됩니다.",
                       "Music loops during slideshow and collage playback."))
            }

            if settings.musicEnabled {
                Section(t("볼륨", "Volume")) {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $settings.musicVolume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if settings.musicTracks.isEmpty {
                    Text(t("추가된 개별 음악이 없습니다", "No individual tracks added"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.musicTracks, id: \.self) { track in
                        Label(track, systemImage: "music.note")
                    }
                    .onDelete(perform: deleteTracks)
                }

                Button {
                    showMusicImporter = true
                } label: {
                    Label(t("음악 추가", "Add Music"), systemImage: "plus.circle.fill")
                }
                .disabled(settings.musicTracks.count >= SettingsStore.maxIndividualTracks)
            } header: {
                Text(t("개별 음악 (최대 \(SettingsStore.maxIndividualTracks)곡)",
                       "Individual Tracks (max \(SettingsStore.maxIndividualTracks))"))
            } footer: {
                Text(t("현재 \(settings.musicTracks.count)/\(SettingsStore.maxIndividualTracks)곡",
                       "\(settings.musicTracks.count)/\(SettingsStore.maxIndividualTracks) tracks"))
            }

            Section {
                if let folder = settings.musicFolderName {
                    Label(t("\(folder) (\(settings.musicFolderTracks.count)곡)",
                            "\(folder) (\(settings.musicFolderTracks.count) tracks)"),
                          systemImage: "folder.fill")
                    Button(role: .destructive) {
                        clearMusicFolder()
                    } label: {
                        Label(t("폴더 등록 해제", "Remove Folder"), systemImage: "trash")
                    }
                } else {
                    Text(t("등록된 폴더가 없습니다", "No folder registered"))
                        .foregroundStyle(.secondary)
                }

                Button {
                    showFolderImporter = true
                } label: {
                    Label(t("폴더 등록", "Register Folder"), systemImage: "folder.badge.plus")
                }
            } header: {
                Text(t("음악 폴더", "Music Folder"))
            } footer: {
                Text(t("폴더를 등록하면 그 안의 모든 음악 파일이 재생 목록에 추가됩니다.",
                       "Registering a folder adds all music files inside to the playlist."))
            }

            if let musicImportError {
                Section {
                    Text(musicImportError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .fileImporter(
            isPresented: $showMusicImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            importMusic(result)
        }
        .fileImporter(
            isPresented: $showFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            importMusicFolder(result)
        }
    }

    private func importMusic(_ result: Result<[URL], Error>) {
        musicImportError = nil
        do {
            let urls = try result.get()
            let fm = FileManager.default
            for src in urls {
                guard settings.musicTracks.count < SettingsStore.maxIndividualTracks else {
                    musicImportError = t(
                        "개별 음악은 최대 \(SettingsStore.maxIndividualTracks)곡까지 추가할 수 있습니다.",
                        "You can add up to \(SettingsStore.maxIndividualTracks) individual tracks."
                    )
                    break
                }
                let needsScope = src.startAccessingSecurityScopedResource()
                defer { if needsScope { src.stopAccessingSecurityScopedResource() } }

                let dest = SettingsStore.musicDirectory.appendingPathComponent(src.lastPathComponent)
                if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
                try fm.copyItem(at: src, to: dest)

                if !settings.musicTracks.contains(src.lastPathComponent) {
                    settings.musicTracks.append(src.lastPathComponent)
                }
            }
        } catch {
            musicImportError = t("음악을 가져오지 못했습니다: \(error.localizedDescription)",
                                 "Failed to import music: \(error.localizedDescription)")
        }
    }

    private func importMusicFolder(_ result: Result<[URL], Error>) {
        musicImportError = nil
        do {
            guard let folder = try result.get().first else { return }
            let needsScope = folder.startAccessingSecurityScopedResource()
            defer { if needsScope { folder.stopAccessingSecurityScopedResource() } }

            let fm = FileManager.default
            let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "caf", "flac", "alac"]
            let contents = try fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            let audioFiles = contents.filter { audioExtensions.contains($0.pathExtension.lowercased()) }

            guard !audioFiles.isEmpty else {
                musicImportError = t("선택한 폴더에 음악 파일이 없습니다.",
                                     "No music files found in the selected folder.")
                return
            }

            clearMusicFolder()
            var names: [String] = []
            for src in audioFiles {
                let dest = SettingsStore.musicDirectory.appendingPathComponent(src.lastPathComponent)
                if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
                try fm.copyItem(at: src, to: dest)
                names.append(src.lastPathComponent)
            }
            settings.musicFolderTracks = names
            settings.musicFolderName = folder.lastPathComponent
        } catch {
            musicImportError = t("폴더를 가져오지 못했습니다: \(error.localizedDescription)",
                                 "Failed to import folder: \(error.localizedDescription)")
        }
    }

    private func deleteTracks(at offsets: IndexSet) {
        let fm = FileManager.default
        for i in offsets {
            let name = settings.musicTracks[i]
            try? fm.removeItem(at: SettingsStore.musicDirectory.appendingPathComponent(name))
        }
        settings.musicTracks.remove(atOffsets: offsets)
    }

    private func clearMusicFolder() {
        let fm = FileManager.default
        for name in settings.musicFolderTracks {
            try? fm.removeItem(at: SettingsStore.musicDirectory.appendingPathComponent(name))
        }
        settings.musicFolderTracks = []
        settings.musicFolderName = nil
    }

    // MARK: Lightroom 계정

    private var lightroomDetail: some View {
        LightroomSetupView()
    }
}
