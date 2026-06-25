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
    @State private var musicImportError: String?

    /// 사이드바 항목.
    enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
        case albums, display, slideshow, collage, music, overlay, lightroom
        var id: String { rawValue }

        /// 사이드바에 노출할 항목. 콜라주 설정은 표시 방식에서 "콜라주"를 고른 뒤
        /// 표시 방식 화면 안에 나타나므로 별도 사이드바 항목으로는 두지 않는다.
        static var sidebarCases: [SettingsSection] {
            allCases.filter { $0 != .collage }
        }

        var title: String {
            switch self {
            case .albums: return "앨범 소스"
            case .display: return "표시 방식"
            case .slideshow: return "슬라이드쇼·콜라주"
            case .collage: return "콜라주"
            case .music: return "배경음악"
            case .overlay: return "위젯 오버레이"
            case .lightroom: return "Lightroom 계정"
            }
        }

        var systemImage: String {
            switch self {
            case .albums: return "photo.on.rectangle.angled"
            case .display: return "rectangle.3.group"
            case .slideshow: return "play.rectangle"
            case .collage: return "square.grid.2x2"
            case .music: return "music.note"
            case .overlay: return "clock"
            case .lightroom: return "camera.filters"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MARK: 사이드바
            List(selection: $selection) {
                ForEach(SettingsSection.sidebarCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationTitle("설정")
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        dismiss()
                    } label: {
                        Label("쇼 시작", systemImage: "play.fill")
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
            // MARK: 디테일
            NavigationStack {
                detailView(for: selection ?? .albums)
                    .navigationTitle((selection ?? .albums).title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showAlbumPicker) {
            AlbumPickerView(source: albumSource, photoLib: photoLib)
        }
    }

    // MARK: - 디테일 화면 분기

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .albums:    albumsDetail
        case .display:   displayDetail
        case .slideshow: slideshowDetail
        case .collage:   slideshowDetail   // 콜라주는 슬라이드쇼(장수)에 통합됨
        case .music:     musicDetail
        case .overlay:   overlayDetail
        case .lightroom: lightroomDetail
        }
    }

    // MARK: 위젯 오버레이

    private var overlayDetail: some View {
        Form {
            Section {
                Toggle("시계·날짜 표시", isOn: $settings.showClock)
            } header: {
                Text("시계")
            }

            Section {
                Toggle("날씨 표시", isOn: $settings.showWeather)
            } header: {
                Text("날씨")
            } footer: {
                Text("현재 위치의 날씨를 액자 위에 표시합니다.")
            }

            // 날씨를 켰을 때 사용 가능 여부를 안내.
            if settings.showWeather {
                Section("날씨 상태") {
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
                            Text("현재 \(temp)")
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
        case .idle:        return "대기 중"
        case .requesting:  return "확인 중…"
        case .denied:      return "위치 권한 없음"
        case .available:   return "사용 가능"
        case .unavailable: return "사용 불가"
        }
    }

    // MARK: 앨범 소스

    private var albumsDetail: some View {
        Form {
            Section("선택된 앨범") {
                if settings.selectedAlbums.isEmpty {
                    Text("아직 앨범을 선택하지 않았습니다")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.selectedAlbums) { selection in
                        HStack {
                            Image(systemName: selection.source == .photoLibrary
                                  ? "photo.on.rectangle" : "camera.filters")
                                .foregroundStyle(.accent)
                            VStack(alignment: .leading) {
                                Text(selection.title).font(.body)
                                Text(selection.source.displayName)
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

            Section("앨범 추가") {
                Button {
                    albumSource = .photoLibrary
                    showAlbumPicker = true
                } label: {
                    Label("iOS 사진 앨범", systemImage: "photo.on.rectangle")
                }

                if AppConfig.Lightroom.partnerApprovalPending {
                    Button {
                        selection = .lightroom
                    } label: {
                        Label("Lightroom (승인 대기 중)", systemImage: "clock.badge.exclamationmark")
                            .foregroundStyle(.orange)
                    }
                } else if AppConfig.Lightroom.isConfigured {
                    Button {
                        albumSource = .lightroom
                        showAlbumPicker = true
                    } label: {
                        Label("Lightroom 앨범", systemImage: "camera.filters")
                    }
                } else {
                    Button {
                        selection = .lightroom
                    } label: {
                        Label("Lightroom 설정 필요", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    // MARK: 표시 방식

    private var displayDetail: some View {
        Form {
            Section("표시 방식") {
                Picker("모드", selection: $settings.displayMode) {
                    ForEach(DisplayMode.selectableCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Text(displayModeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 쇼(슬라이드쇼/콜라주) 장수·채움 설정

    @ViewBuilder
    private var showCountSections: some View {
        Section {
            Picker("장수 방식", selection: $settings.collageCountMode) {
                ForEach(CollageCountMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if settings.collageCountMode == .fixed {
                HStack {
                    Text("한 화면 사진 수")
                    Spacer()
                    Text("\(settings.collageCount)장").foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(settings.collageCount) },
                    set: { settings.collageCount = Int($0) }
                ), in: 1...9, step: 1)
            } else {
                HStack {
                    Text("범위")
                    Spacer()
                    Text("\(min(settings.collageRangeMin, settings.collageRangeMax))~\(max(settings.collageRangeMin, settings.collageRangeMax))장")
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $settings.collageRangeMin, in: 1...9) {
                    Text("최소 \(settings.collageRangeMin)장")
                }
                Stepper(value: $settings.collageRangeMax, in: 1...9) {
                    Text("최대 \(settings.collageRangeMax)장")
                }
            }
        } header: {
            Text("장수")
        } footer: {
            Text("1장이면 한 장씩 슬라이드쇼, 2장 이상이면 콜라주 형태로 재생됩니다.")
        }
    }

    private var displayModeDescription: String {
        switch settings.displayMode {
        case .slideshow: return "장수에 따라 한 장씩(1장) 또는 콜라주(2장 이상)로 재생합니다."
        case .collage:   return "여러 장을 한 화면에 모자이크로 배치합니다."
        case .grid:      return "전체 사진을 격자로 스크롤하며 봅니다."
        }
    }

    // MARK: 슬라이드쇼

    private var slideshowDetail: some View {
        Form {
            // 장수(1장=한 장씩, 2장 이상=콜라주)
            showCountSections

            Section("사진 채움 방식") {
                Picker("채움 방식", selection: $settings.slideshowFitStyle) {
                    ForEach(CollageFitStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.slideshowFitStyle == .blurFill
                     ? "사진 전체를 보여주고, 남는 여백은 블러 배경으로 채웁니다."
                     : "사진 전체를 비율 그대로 보여줍니다(남는 부분은 검은 여백).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("전환 간격")
                    Spacer()
                    Text("\(Int(settings.slideInterval))초").foregroundStyle(.secondary)
                }
                Slider(value: $settings.slideInterval, in: 2...60, step: 1) {
                    Text("전환 간격")
                } minimumValueLabel: {
                    Text("2초").font(.caption2)
                } maximumValueLabel: {
                    Text("60초").font(.caption2)
                }
            } header: {
                Text("전환 속도")
            } footer: {
                Text("사진이 다음 장으로 넘어가는 간격입니다. (2초 ~ 60초)")
            }

            // 한 장씩(단일) 재생일 때만 의미 있는 효과.
            if settings.isSinglePhotoShow {
                Section("전환 효과") {
                    Picker("전환 효과", selection: $settings.slideTransition) {
                        ForEach(SlideTransition.allCases) { transition in
                            Text(transition.displayName).tag(transition)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // 랜덤 선택 모드: 효과를 최대 5개 골라 무작위 적용.
                if settings.slideTransition == .randomSelected {
                    Section {
                        ForEach(SlideTransition.concreteEffects) { effect in
                            let isOn = settings.selectedTransitions.contains(effect)
                            Button {
                                toggleTransition(effect)
                            } label: {
                                HStack {
                                    Text(effect.displayName)
                                    Spacer()
                                    if isOn {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                            .disabled(!isOn && settings.selectedTransitions.count >= SlideTransition.maxRandomSelection)
                        }
                    } header: {
                        Text("적용할 효과 (최대 \(SlideTransition.maxRandomSelection)개)")
                    } footer: {
                        Text("선택한 \(settings.selectedTransitions.count)개 효과 중 무작위로 적용됩니다.")
                    }
                }
                Section("효과") {
                    Toggle("Ken Burns 효과", isOn: $settings.kenBurnsEnabled)
                }
            }
        }
    }

    /// 랜덤 선택 효과 목록에서 토글(최대 개수 초과 시 추가 안 함).
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
                Toggle("배경음악 사용", isOn: $settings.musicEnabled)
            } footer: {
                Text("슬라이드쇼·콜라주 재생 중 음악이 반복 재생됩니다.")
            }

            if settings.musicEnabled {
                Section("볼륨") {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $settings.musicVolume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
            }

            Section("재생 목록") {
                if settings.musicTracks.isEmpty {
                    Text("추가된 음악이 없습니다")
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
                    Label("음악 추가", systemImage: "plus.circle.fill")
                }
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
    }

    private func importMusic(_ result: Result<[URL], Error>) {
        musicImportError = nil
        do {
            let urls = try result.get()
            let fm = FileManager.default
            for src in urls {
                // 보안 스코프 자원 접근(외부 Files 위치).
                let needsScope = src.startAccessingSecurityScopedResource()
                defer { if needsScope { src.stopAccessingSecurityScopedResource() } }

                let dest = SettingsStore.musicDirectory.appendingPathComponent(src.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }
                try fm.copyItem(at: src, to: dest)

                if !settings.musicTracks.contains(src.lastPathComponent) {
                    settings.musicTracks.append(src.lastPathComponent)
                }
            }
        } catch {
            musicImportError = "음악을 가져오지 못했습니다: \(error.localizedDescription)"
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

    // MARK: Lightroom 계정

    private var lightroomDetail: some View {
        LightroomSetupView()
    }
}
