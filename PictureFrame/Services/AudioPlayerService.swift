import Foundation
import AVFoundation
import Combine

/// 배경음악 재생을 담당한다. 트랙 목록을 순회하며 반복 재생한다.
@MainActor
final class AudioPlayerService: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTrackName: String?

    private var player: AVAudioPlayer?
    private var tracks: [URL] = []
    private var index = 0
    private var volume: Float = 0.6

    // MARK: - 설정

    /// 재생할 트랙 목록을 갱신한다.
    func setTracks(_ urls: [URL]) {
        tracks = urls
        if index >= tracks.count { index = 0 }
    }

    func setVolume(_ value: Double) {
        volume = Float(max(0, min(1, value)))
        player?.volume = volume
    }

    // MARK: - 재생 제어

    /// 음악 재생을 시작한다. 이미 재생 중이면 무시.
    func start() {
        guard !tracks.isEmpty else { return }
        if isPlaying { return }
        configureSession(active: true)
        if player == nil {
            startCurrent()
        } else {
            player?.play()
            isPlaying = true
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        configureSession(active: false)
    }

    func next() {
        guard !tracks.isEmpty else { return }
        index = (index + 1) % tracks.count
        startCurrent()
    }

    // MARK: - 내부

    private func startCurrent() {
        guard tracks.indices.contains(index) else { return }
        let url = tracks[index]
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.volume = volume
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            isPlaying = true
            currentTrackName = url.deletingPathExtension().lastPathComponent
        } catch {
            isPlaying = false
            currentTrackName = nil
        }
    }

    private func configureSession(active: Bool) {
        let session = AVAudioSession.sharedInstance()
        if active {
            // 무음 스위치/잠금 상태에서도 재생되도록 playback 카테고리 사용.
            try? session.setCategory(.playback, mode: .default)
        }
        try? session.setActive(active, options: active ? [] : [.notifyOthersOnDeactivation])
    }
}

// MARK: - 곡 종료 시 다음 곡

extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.next() }
    }
}
