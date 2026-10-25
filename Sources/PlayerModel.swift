import Foundation
import AVFoundation
import MediaPlayer
import Combine

final class PlayerModel: ObservableObject {
    @Published var title = ""
    @Published var isPlaying = false
    @Published var current: Double = 0
    @Published var duration: Double = 0
    @Published var rate: Float = 1.0
    @Published var currentCollection = ""
    @Published var sleepMode: SleepMode = .none
    @Published var sleepRemaining: Int = 0

    enum SleepMode: Equatable {
        case none
        case time
        case episodes
    }

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var currentURL: URL?
    private var queue: [Track] = []
    private var index = 0
    private var sleepTimer: Timer?
    private var endObserver: NSObjectProtocol?

    init() {
        setupRemoteCommands()
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.saveProgress()
        }
    }

    var hasTrack: Bool { !title.isEmpty }

    func play(_ track: Track, queue: [Track]) {
        self.queue = queue
        self.index = queue.firstIndex(of: track) ?? 0
        load(track)
    }

    private func load(_ track: Track) {
        clear()
        currentURL = track.url
        title = track.name
        currentCollection = track.collection
        let item = AVPlayerItem(url: track.url)
        player = AVPlayer(playerItem: item)
        addTimeObserver()
        let saved = UserDefaults.standard.double(forKey: "pos-" + track.url.lastPathComponent)
        if saved > 0 {
            player?.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
        }
        player?.rate = rate
        player?.play()
        isPlaying = true
        observeEnd()
        updateNowPlaying()
        UserDefaults.standard.set(track.url.path, forKey: "lastTrackPath")
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

    func next() {
        guard !queue.isEmpty else { return }
        if index + 1 < queue.count {
            index += 1
            load(queue[index])
        } else {
            player?.pause()
            isPlaying = false
        }
    }

    func prev() {
        guard !queue.isEmpty else { return }
        if current > 5 {
            seek(to: 0)
            return
        }
        if index > 0 {
            index -= 1
            load(queue[index])
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        current = seconds
    }

    func setRate(_ r: Float) {
        rate = r
        if isPlaying { player?.rate = r }
    }

    func setSleepTime(_ minutes: Int) {
        sleepMode = .time
        sleepRemaining = minutes * 60
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.sleepRemaining > 0 {
                self.sleepRemaining -= 1
                if self.sleepRemaining == 0 {
                    self.stopForSleep()
                }
            }
        }
    }

    func setSleepEpisodes(_ n: Int) {
        sleepMode = .episodes
        sleepRemaining = n
        sleepTimer?.invalidate()
    }

    func cancelSleep() {
        sleepMode = .none
        sleepRemaining = 0
        sleepTimer?.invalidate()
        sleepTimer = nil
    }

    private func stopForSleep() {
        player?.pause()
        isPlaying = false
        cancelSleep()
        updateNowPlaying()
    }

    private func onEnded() {
        saveProgress()
        if sleepMode == .episodes {
            sleepRemaining -= 1
            if sleepRemaining <= 0 {
                stopForSleep()
                return
            }
        }
        next()
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

    private func observeEnd() {
        if let o = endObserver {
            NotificationCenter.default.removeObserver(o)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.onEnded()
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
        cc.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        cc.previousTrackCommand.addTarget { [weak self] _ in
            self?.prev()
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
