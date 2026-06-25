import SwiftUI

/// 특정 출처(iOS 사진 / Lightroom)의 앨범 목록을 표시하고 선택하게 해주는 시트.
struct AlbumPickerView: View {
    let source: PhotoSourceKind
    let photoLib: PhotoLibraryService

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var lightroomAuth: LightroomAuthService
    @Environment(\.dismiss) private var dismiss

    @State private var albums: [Album] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("앨범 로딩 중…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
                } else if albums.isEmpty {
                    ContentUnavailableView("앨범 없음", systemImage: "photo.on.rectangle")
                } else {
                    List(albums) { album in
                        albumRow(album)
                    }
                }
            }
            .navigationTitle(source == .photoLibrary ? "iOS 앨범 선택" : "Lightroom 앨범 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
        .task { await loadAlbums() }
    }

    @ViewBuilder
    private func albumRow(_ album: Album) -> some View {
        let isSelected = settings.selectedAlbums.contains { $0.albumID == rawAlbumID(album) }

        Button {
            toggleAlbum(album)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title).foregroundStyle(.primary)
                    if let count = album.estimatedCount {
                        Text("\(count)장").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(.accent)
                }
            }
        }
    }

    private func loadAlbums() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            switch source {
            case .photoLibrary:
                albums = try await photoLib.fetchAlbums()
            case .lightroom:
                guard !AppConfig.Lightroom.partnerApprovalPending else {
                    error = "Adobe Lightroom 파트너 API 승인 대기 중입니다. 승인 후 사용할 수 있습니다."
                    return
                }
                guard AppConfig.Lightroom.isConfigured else {
                    error = "Lightroom Client ID 가 설정되지 않았습니다."
                    return
                }
                if !(await lightroomAuth.isAuthenticated) {
                    try await lightroomAuth.signIn()
                }
                let service = LightroomService(auth: lightroomAuth)
                albums = try await service.fetchAlbums()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func toggleAlbum(_ album: Album) {
        let id = rawAlbumID(album)
        let (catalogID, albumID): (String?, String)

        if source == .lightroom, album.id.contains("/") {
            let parts = album.id.split(separator: "/", maxSplits: 1)
            catalogID = String(parts[0])
            albumID = String(parts[1])
        } else {
            catalogID = nil
            albumID = id
        }

        let selection = AlbumSelection(
            source: source,
            albumID: albumID,
            title: album.title,
            catalogID: catalogID
        )

        if settings.selectedAlbums.contains(where: { $0.albumID == id }) {
            settings.removeAlbum(selection)
        } else {
            settings.addAlbum(selection)
        }
    }

    private func rawAlbumID(_ album: Album) -> String {
        if source == .lightroom, album.id.contains("/") {
            return String(album.id.split(separator: "/", maxSplits: 1).last ?? Substring(album.id))
        }
        return album.id
    }
}
