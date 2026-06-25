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
    /// 진행 중인 prefetch 작업(사진 ID 기준, 중복 다운로드 방지).
    private var prefetchTasks: [String: Task<Void, Never>] = [:]

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

        // 이전 prefetch 작업 정리(목록이 바뀌었으므로).
        prefetchTasks.values.forEach { $0.cancel() }
        prefetchTasks.removeAll()

        photos = allPhotos.shuffled()
        currentIndex = 0
    }

    // MARK: - 슬라이드 타이머

    /// 슬라이드 타이머 시작.
    /// - Parameter step: 한 번에 넘길 사진 수 (슬라이드쇼=1, 콜라주=한 장면의 사진 수).
    func startSlideTimer(step: Int = 1) {
        stopSlideTimer()
        guard photos.count > 1 else { return }
        slideTimer = Timer.scheduledTimer(withTimeInterval: settings.slideInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advance(by: step) }
        }
    }

    /// 콜라주 전용 타이머. 매 틱마다 현재 장면의 사진 수만큼 넘긴다
    /// (장수가 고정이든 범위 무작위든 항상 현재 장면 기준으로 진행).
    func startCollageTimer() {
        stopSlideTimer()
        guard photos.count > 1 else { return }
        slideTimer = Timer.scheduledTimer(withTimeInterval: settings.slideInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let step = self.settings.collagePhotoCount(forScene: self.currentIndex)
                self.advance(by: max(1, step))
            }
        }
    }

    func stopSlideTimer() {
        slideTimer?.invalidate()
        slideTimer = nil
    }

    func advance(by step: Int = 1) {
        guard !photos.isEmpty else { return }
        currentIndex = (currentIndex + step) % photos.count
    }

    func previous() {
        guard !photos.isEmpty else { return }
        currentIndex = (currentIndex - 1 + photos.count) % photos.count
    }

    // MARK: - 이미지 로드

    func loadImage(for photo: FramePhoto, targetSize: CGSize) async -> UIImage? {
        // 원본이 아무리 커도 화면 크기에 맞는 해상도로만 요청/다운로드한다.
        let size = clampToScreen(targetSize)

        // 1) 메모리 캐시 (즉시).
        if let cached = ImageCache.shared.memoryImage(for: photo.id, size: size) {
            return cached
        }
        // 2) 디스크 캐시 (앱 재실행 후에도 유지) → 메모리로 승격.
        if let disk = await ImageCache.shared.diskImage(for: photo.id, size: size) {
            ImageCache.shared.storeMemory(disk, for: photo.id, size: size)
            return disk
        }
        // 3) 화면 크기에 맞춰 다운로드 후 메모리+디스크 저장.
        let provider: PhotoProvider = photo.source == .photoLibrary ? photoLib : lightroom
        guard let image = try? await provider.loadImage(for: photo, targetSize: size) else {
            return nil
        }
        ImageCache.shared.store(image, for: photo.id, size: size)
        return image
    }

    /// 메모리 캐시에 이미 있는 이미지를 동기적으로 반환한다.
    /// 전환 순간 새 뷰가 검은 화면으로 삽입되어 효과가 어색해지는 것을 막기 위해,
    /// (prefetch 로 채워진) 캐시 이미지를 즉시 표시하는 데 사용한다.
    func cachedImage(for photo: FramePhoto, targetSize: CGSize) -> UIImage? {
        let size = clampToScreen(targetSize)
        return ImageCache.shared.memoryImage(for: photo.id, size: size)
    }

    /// 대상 크기를 기기 화면(포인트) 범위로 제한한다.
    /// 큰 사진을 전체 해상도로 받지 않고 iPad 화면에 맞는 크기로 축소 요청하기 위함.
    private func clampToScreen(_ size: CGSize) -> CGSize {
        let screen = UIScreen.main.bounds.size
        // 화면보다 큰 요청은 화면 크기로 제한. 0 이하 요청은 화면 전체로 대체.
        let w = size.width > 0 ? min(size.width, screen.width) : screen.width
        let h = size.height > 0 ? min(size.height, screen.height) : screen.height
        return CGSize(width: w, height: h)
    }

    // MARK: - 미리 받기(Prefetch)

    /// 슬라이드쇼에서 곧 표시될 다음 사진들을 미리 백그라운드로 받아 캐시에 채운다.
    /// 전환 시 로딩 지연 없이 매끄럽게 넘어가도록 한다.
    func prefetchUpcoming(count: Int = 3, targetSize: CGSize) {
        guard !photos.isEmpty, targetSize.width > 0 else { return }
        for offset in 1...count {
            let idx = (currentIndex + offset) % photos.count
            let photo = photos[idx]
            let id = photo.id
            if ImageCache.shared.memoryImage(for: id, size: targetSize) != nil { continue }
            if prefetchTasks[id] != nil { continue }
            prefetchTasks[id] = Task { [weak self] in
                _ = await self?.loadImage(for: photo, targetSize: targetSize)
                self?.prefetchTasks[id] = nil
            }
        }
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
