import Foundation
import AVFoundation
import MediaPlayer

final class PlayerModel: ObservableObject {
    @Published var title = "未播放"
    @Published var isPlaying = false
    @Published var current: Double = 0
    @Published var duration: Double = 0
    @Published var rate: Float = 1.0

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var currentURL: URL?

    init() {
        setupRemoteCommands()
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.saveProgress()
        }
    }

    func open(url: URL) {
        clear()
        currentURL = url
        title = url.deletingPathExtension().lastPathComponent
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        addTimeObserver()
        let saved = UserDefaults.standard.double(forKey: "pos-" + url.lastPathComponent)
        if saved > 0 {
            player?.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
        }
        player?.rate = rate
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    func toggle() {
        guard let p = player else { return }
        if p.rate == 0 {
            p.play()
            isPlaying = true
        } else {
            p.pause()
            isPlaying = false
        }
        updateNowPlaying()
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        current = seconds
    }

    func setRate(_ r: Float) {
        rate = r
        if isPlaying { player?.rate = r }
    }

    private func clear() {
        if let p = player, let o = timeObserver {
            p.removeTimeObserver(o)
        }
        timeObserver = nil
        player?.pause()
        player = nil
    }

    private func addTimeObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.current = time.seconds
            if let d = player.currentItem?.duration.seconds, d.isFinite {
                self.duration = d
            }
        }
    }

    private func saveProgress() {
        guard let url = currentURL, current > 1 else { return }
        UserDefaults.standard.set(current, forKey: "pos-" + url.lastPathComponent)
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = current
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            self?.isPlaying = true
            self?.updateNowPlaying()
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            self?.isPlaying = false
            self?.updateNowPlaying()
            return .success
        }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: e.positionTime)
            return .success
        }
    }
}
