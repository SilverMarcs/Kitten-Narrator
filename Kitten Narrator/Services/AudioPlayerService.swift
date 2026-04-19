import AVFoundation
import MediaPlayer

@Observable
final class AudioPlayerService: NSObject {
    var isPlaying = false
    var currentPosition: TimeInterval = 0
    var duration: TimeInterval = 0
    var rate: Float = 1.0

    var isStreamingGeneration = false

    // MARK: - File-based playback

    private var audioPlayer: AVAudioPlayer?

    // MARK: - Streaming playback

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var streamingFormat: AVAudioFormat?
    private var totalStreamedFrames: Int = 0
    private(set) var accumulatedSamples: [Float] = []

    // MARK: - Shared

    private var positionTask: Task<Void, Never>?
    private var seekGeneration: Int = 0
    var onPlaybackFinished: (() -> Void)?

    // MARK: - File Playback

    func play(url: URL, startPosition: TimeInterval = 0, rate: Float = 1.0) throws {
        setupAudioSession()
        stopAll()
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
        startFilePositionTracking()
    }

    // MARK: - Streaming Playback

    func beginStreaming(sampleRate: Int) throws {
        setupAudioSession()
        stopAll()

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: Double(sampleRate),
            channels: 1
        ) else { return }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()

        audioEngine = engine
        playerNode = player
        streamingFormat = format
        totalStreamedFrames = 0
        accumulatedSamples = []
        isStreamingGeneration = true
        isPlaying = false
        currentPosition = 0
        duration = 0
    }

    func appendAudio(_ samples: [Float]) {
        guard let player = playerNode, let format = streamingFormat else { return }
        guard !samples.isEmpty else { return }

        let isFirstChunk = accumulatedSamples.isEmpty

        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        )!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            buffer.floatChannelData![0].update(from: src.baseAddress!, count: samples.count)
        }

        player.scheduleBuffer(buffer)
        accumulatedSamples.append(contentsOf: samples)
        totalStreamedFrames += samples.count
        duration = Double(totalStreamedFrames) / format.sampleRate

        if isFirstChunk {
            player.play()
            isPlaying = true
            startStreamPositionTracking()
        }
    }

    func finishStreaming() {
        isStreamingGeneration = false
        scheduleEndOfPlaybackHandler()
    }

    private func scheduleEndOfPlaybackHandler() {
        guard let player = playerNode, let format = streamingFormat else { return }
        let generation = seekGeneration
        let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1)!
        silence.frameLength = 0
        player.scheduleBuffer(silence) { [weak self] in
            Task { @MainActor in
                guard let self,
                      self.playerNode != nil,
                      self.seekGeneration == generation else { return }
                self.isPlaying = false
                self.currentPosition = self.duration
                self.stopPositionTracking()
                self.onPlaybackFinished?()
            }
        }
    }

    // MARK: - Shared Controls

    func pause() {
        if let player = playerNode {
            player.pause()
        } else {
            audioPlayer?.pause()
        }
        isPlaying = false
        stopPositionTracking()
        updateNowPlayingElapsed()
    }

    func resume() {
        if let player = playerNode {
            player.play()
            startStreamPositionTracking()
        } else {
            audioPlayer?.play()
            startFilePositionTracking()
        }
        isPlaying = true
        updateNowPlayingElapsed()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func seek(to position: TimeInterval) {
        let clamped = min(max(position, 0), duration)

        if let player = playerNode, let format = streamingFormat {
            let startSample = Int(clamped * format.sampleRate)
            guard startSample < accumulatedSamples.count else { return }

            // Invalidate any pending end-of-playback handler
            seekGeneration += 1

            player.stop()
            let remaining = Array(accumulatedSamples[startSample...])
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(remaining.count)
            )!
            buffer.frameLength = AVAudioFrameCount(remaining.count)
            remaining.withUnsafeBufferPointer { src in
                buffer.floatChannelData![0].update(from: src.baseAddress!, count: remaining.count)
            }
            player.scheduleBuffer(buffer)
            player.play()
            currentPosition = clamped
            streamSeekOffset = clamped
            isPlaying = true
            startStreamPositionTracking()

            // Re-schedule end-of-playback handler for the new buffer
            if !isStreamingGeneration {
                scheduleEndOfPlaybackHandler()
            }
        } else {
            audioPlayer?.currentTime = clamped
            currentPosition = clamped
        }
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
        stopAll()
    }

    private func stopAll() {
        audioPlayer?.stop()
        audioPlayer = nil

        playerNode?.stop()
        audioEngine?.stop()
        playerNode = nil
        audioEngine = nil
        streamingFormat = nil
        accumulatedSamples = []
        totalStreamedFrames = 0
        isStreamingGeneration = false
        streamSeekOffset = 0
        seekGeneration += 1

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

    private var streamSeekOffset: TimeInterval = 0

    private func startFilePositionTracking() {
        stopPositionTracking()
        positionTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.currentPosition = self.audioPlayer?.currentTime ?? 0
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func startStreamPositionTracking() {
        stopPositionTracking()
        positionTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self,
                      let player = self.playerNode,
                      let nodeTime = player.lastRenderTime,
                      nodeTime.isSampleTimeValid,
                      let playerTime = player.playerTime(forNodeTime: nodeTime)
                else {
                    try? await Task.sleep(for: .milliseconds(33))
                    continue
                }
                let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
                self.currentPosition = self.streamSeekOffset + max(0, elapsed)
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func stopPositionTracking() {
        positionTask?.cancel()
        positionTask = nil
    }

    // MARK: - Now Playing Info

    func updateNowPlayingInfo(title: String, artist: String = "Narrator", artworkURL: URL? = nil) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPosition
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(rate) : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        if let artworkURL {
            Task {
                guard let (data, _) = try? await URLSession.shared.data(from: artworkURL) else { return }
                #if os(iOS)
                guard let uiImage = UIImage(data: data) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: uiImage.size) { _ in uiImage }
                #elseif os(macOS)
                guard let nsImage = NSImage(data: data) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                #endif
                MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = artwork
            }
        }
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
