import Foundation
import UIKit
import Combine

/// 액자 화면의 핵심 로직을 담당한다.
/// - 선택된 앨범에서 사진 목록을 로드/합산하고 셔플한다.
/// - 현재 인덱스를 관리하며 타이머로 슬라이드 전환을 주도한다.
/// - 이미지 로드 요청을 출처별 Provider 에 위임한다.
@MainActor
final class FrameViewModel: ObservableObject {
    @Published private(set) var photos: [FramePhoto] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let settings: SettingsStore
    private let photoLib: PhotoLibraryService
    private let lightroom: LightroomService

    private var slideTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(settings: SettingsStore, photoLib: PhotoLibraryService, lightroom: LightroomService) {
        self.settings = settings
        self.photoLib = photoLib
        self.lightroom = lightroom

        settings.$selectedAlbums
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.reload() }
            }
            .store(in: &cancellables)
    }

    // MARK: - 로드

    func reload() async {
        guard !settings.selectedAlbums.isEmpty else {
            photos = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var allPhotos: [FramePhoto] = []
        for selection in settings.selectedAlbums {
            do {
                let provider: PhotoProvider = selection.source == .photoLibrary ? photoLib : lightroom
                let fetched = try await provider.fetchPhotos(in: selection)
                allPhotos.append(contentsOf: fetched)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        photos = allPhotos.shuffled()
        currentIndex = 0
    }

    // MARK: - 슬라이드 타이머

    func startSlideTimer() {
        stopSlideTimer()
        guard photos.count > 1 else { return }
        slideTimer = Timer.scheduledTimer(withTimeInterval: settings.slideInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advance() }
        }
    }

    func stopSlideTimer() {
        slideTimer?.invalidate()
        slideTimer = nil
    }

    func advance() {
        guard !photos.isEmpty else { return }
        currentIndex = (currentIndex + 1) % photos.count
    }

    func previous() {
        guard !photos.isEmpty else { return }
        currentIndex = (currentIndex - 1 + photos.count) % photos.count
    }

    // MARK: - 이미지 로드

    func loadImage(for photo: FramePhoto, targetSize: CGSize) async -> UIImage? {
        let provider: PhotoProvider = photo.source == .photoLibrary ? photoLib : lightroom
        return try? await provider.loadImage(for: photo, targetSize: targetSize)
    }

    // MARK: - 콜라주용 사진 슬라이스

    /// 현재 인덱스 기준으로 콜라주에 사용할 `count` 장 반환.
    func collageBatch(count: Int) -> [FramePhoto] {
        guard !photos.isEmpty else { return [] }
        let n = min(count, photos.count)
        var result: [FramePhoto] = []
        for i in 0..<n {
            result.append(photos[(currentIndex + i) % photos.count])
        }
        return result
    }
}
