import AVFoundation
import MediaPlayer

@Observable
final class AudioPlayerService: NSObject {
    var isPlaying = false
    var currentPosition: TimeInterval = 0
    var duration: TimeInterval = 0
    var rate: Float = 1.0

    private var audioPlayer: AVAudioPlayer?
    private var positionTask: Task<Void, Never>?

    var onPlaybackFinished: (() -> Void)?

    func play(url: URL, startPosition: TimeInterval = 0, rate: Float = 1.0) throws {
        setupAudioSession()
        audioPlayer?.stop()
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.enableRate = true
        audioPlayer?.rate = rate
        audioPlayer?.currentTime = startPosition
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        self.rate = rate
        isPlaying = true
        duration = audioPlayer?.duration ?? 0
        currentPosition = startPosition
        startPositionTracking()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopPositionTracking()
        updateNowPlayingElapsed()
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startPositionTracking()
        updateNowPlayingElapsed()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func seek(to position: TimeInterval) {
        let clamped = min(max(position, 0), duration)
        audioPlayer?.currentTime = clamped
        currentPosition = clamped
        updateNowPlayingElapsed()
    }

    func skipForward(_ seconds: TimeInterval = 15) {
        seek(to: currentPosition + seconds)
    }

    func skipBackward(_ seconds: TimeInterval = 15) {
        seek(to: currentPosition - seconds)
    }

    func setRate(_ newRate: Float) {
        let clamped = min(max(newRate, 0.5), 2.0)
        audioPlayer?.rate = clamped
        self.rate = clamped
        updateNowPlayingElapsed()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentPosition = 0
        duration = 0
        stopPositionTracking()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        #endif
    }

    // MARK: - Position Tracking

    private func startPositionTracking() {
        stopPositionTracking()
        positionTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.currentPosition = self.audioPlayer?.currentTime ?? 0
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopPositionTracking() {
        positionTask?.cancel()
        positionTask = nil
    }

    // MARK: - Now Playing Info

    func updateNowPlayingInfo(title: String, artist: String = "Narrator") {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPosition
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(rate) : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingElapsed() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPosition
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(rate) : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Remote Commands

    func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)

        center.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentPosition = self.duration
            self.stopPositionTracking()
            self.onPlaybackFinished?()
        }
    }
}
