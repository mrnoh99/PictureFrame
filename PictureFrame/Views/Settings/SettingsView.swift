import SwiftUI

/// 앨범 선택, 표시 모드, 슬라이드쇼·콜라주 옵션을 설정하는 시트.
struct SettingsView: View {
    let photoLib: PhotoLibraryService
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var lightroomAuth: LightroomAuthService
    @Environment(\.dismiss) private var dismiss

    @State private var showAlbumPicker = false
    @State private var albumSource: PhotoSourceKind = .photoLibrary

    var body: some View {
        NavigationStack {
            Form {
                // MARK: 선택된 앨범
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
                                    Text(selection.source.displayName).font(.caption).foregroundStyle(.secondary)
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

                // MARK: 앨범 추가
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
                        NavigationLink {
                            LightroomSetupView()
                        } label: {
                            Label("Lightroom 설정", systemImage: "camera.filters")
                        }
                    }
                }

                // MARK: 표시 모드
                Section("표시 방식") {
                    Picker("모드", selection: $settings.displayMode) {
                        ForEach(DisplayMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: 슬라이드쇼 옵션
                if settings.displayMode == .slideshow {
                    Section("슬라이드쇼") {
                        HStack {
                            Text("전환 간격")
                            Spacer()
                            Text("\(Int(settings.slideInterval))초")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.slideInterval, in: 3...30, step: 1)

                        Toggle("Ken Burns 효과", isOn: $settings.kenBurnsEnabled)
                    }
                }

                // MARK: 콜라주 옵션
                if settings.displayMode == .collage {
                    Section("콜라주") {
                        HStack {
                            Text("사진 수")
                            Spacer()
                            Text("\(settings.collageCount)장")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(settings.collageCount) },
                            set: { settings.collageCount = Int($0) }
                        ), in: 2...9, step: 1)
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showAlbumPicker) {
            AlbumPickerView(source: albumSource, photoLib: photoLib)
        }
    }
}
