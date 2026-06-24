import SwiftUI

/// 앨범 선택, 표시 모드, 슬라이드쇼·콜라주 옵션을 설정하는 화면.
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

    /// 사이드바 항목.
    enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
        case albums, display, slideshow, collage, lightroom
        var id: String { rawValue }

        var title: String {
            switch self {
            case .albums: return "앨범 소스"
            case .display: return "표시 방식"
            case .slideshow: return "슬라이드쇼"
            case .collage: return "콜라주"
            case .lightroom: return "Lightroom 계정"
            }
        }

        var systemImage: String {
            switch self {
            case .albums: return "photo.on.rectangle.angled"
            case .display: return "rectangle.3.group"
            case .slideshow: return "play.rectangle"
            case .collage: return "square.grid.2x2"
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
        case .lightroom: lightroomDetail
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
            Section("전환") {
                HStack {
                    Text("전환 간격")
                    Spacer()
                    Text("\(Int(settings.slideInterval))초").foregroundStyle(.secondary)
                }
                Slider(value: $settings.slideInterval, in: 3...30, step: 1)
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

    // MARK: Lightroom 계정

    private var lightroomDetail: some View {
        LightroomSetupView()
    }
}
