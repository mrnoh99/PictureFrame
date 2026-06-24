import SwiftUI
import UniformTypeIdentifiers

/// 앨범 선택, 표시 모드, 슬라이드쇼·콜라주·배경음악 옵션을 설정하는 화면.
/// iPad 가로 모드에 맞춰 사이드바 + 디테일 형태의 Split View 로 구성.
struct SettingsView: View {
    let photoLib: PhotoLibraryService
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var lightroomAuth: LightroomAuthService
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

        var title: String {
            switch self {
            case .albums: return "앨범 소스"
            case .display: return "표시 방식"
            case .slideshow: return "슬라이드쇼"
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
                ForEach(SettingsSection.allCases) { section in
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
                Text("Developed by JaiSung NOH MD 2026")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
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
        case .collage:   collageDetail
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
                Toggle("날씨 표시", isOn: $settings.showWeather)
            } header: {
                Text("오버레이")
            } footer: {
                Text("액자 화면 위에 시계와 날씨를 표시합니다. 날씨는 위치 권한과 WeatherKit 설정이 필요하며, 사용할 수 없으면 자동으로 숨겨집니다.")
            }
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

                if AppConfig.Lightroom.isConfigured {
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
                    ForEach(DisplayMode.allCases) { mode in
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

    private var displayModeDescription: String {
        switch settings.displayMode {
        case .slideshow: return "한 장씩 Ken Burns 효과로 전환하며 보여줍니다."
        case .collage:   return "여러 장을 한 화면에 모자이크로 배치합니다."
        case .grid:      return "전체 사진을 격자로 스크롤하며 봅니다."
        }
    }

    // MARK: 슬라이드쇼

    private var slideshowDetail: some View {
        Form {
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
            Section("전환 효과") {
                Picker("전환 효과", selection: $settings.slideTransition) {
                    ForEach(SlideTransition.allCases) { transition in
                        Text(transition.displayName).tag(transition)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("효과") {
                Toggle("Ken Burns 효과", isOn: $settings.kenBurnsEnabled)
            }
        }
    }

    // MARK: 콜라주

    private var collageDetail: some View {
        Form {
            Section("레이아웃") {
                HStack {
                    Text("사진 수")
                    Spacer()
                    Text("\(settings.collageCount)장").foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(settings.collageCount) },
                    set: { settings.collageCount = Int($0) }
                ), in: 2...9, step: 1)
            }
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
