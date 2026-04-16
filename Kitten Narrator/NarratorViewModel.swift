import Foundation
import KittenTTS
import SwiftUI

@Observable
final class NarratorViewModel {

    // MARK: - App State

    enum AppState: Equatable {
        case loading
        case downloading(Double)
        case ready
        case error(String)
    }

    var appState: AppState = .loading

    // MARK: - Playback State

    var currentItem: NarratorItem?
    var isGenerating = false
    var generatingItemID: UUID?
    var showNowPlaying = false
    var showAddContent = false

    // MARK: - Settings

    var selectedVoice: String {
        didSet { UserDefaults.standard.set(selectedVoice, forKey: "narrator_voice") }
    }

    var playbackSpeed: Float {
        didSet { UserDefaults.standard.set(playbackSpeed, forKey: "narrator_speed") }
    }

    // MARK: - Services

    let audioPlayer = AudioPlayerService()
    private var tts: KittenTTS?

    // MARK: - Init

    init() {
        self.selectedVoice = UserDefaults.standard.string(forKey: "narrator_voice") ?? "bella"
        let savedSpeed = UserDefaults.standard.float(forKey: "narrator_speed")
        self.playbackSpeed = savedSpeed > 0 ? savedSpeed : 1.0
    }

    // MARK: - Initialization

    func initialize() async {
        let config = KittenTTSConfig(model: .nanoInt8)

        if !KittenTTS.isModelCached(for: config) {
            appState = .downloading(0)
        }

        do {
            tts = try await KittenTTS(config) { [weak self] progress in
                Task { @MainActor in
                    if case .downloading = self?.appState {
                        self?.appState = .downloading(progress)
                    }
                }
            }
            appState = .ready
            audioPlayer.setupRemoteCommands()
            audioPlayer.onPlaybackFinished = { [weak self] in
                self?.handlePlaybackFinished()
            }
        } catch {
            appState = .error(error.localizedDescription)
        }
    }

    // MARK: - Playback

    func playItem(_ item: NarratorItem) async {
        if item.hasGeneratedAudio && item.voiceIdentifier == selectedVoice {
            startPlayback(item)
            return
        }
        await generateAndPlay(item)
    }

    private func startPlayback(_ item: NarratorItem) {
        saveCurrentPosition()
        currentItem = item
        showNowPlaying = true

        do {
            try audioPlayer.play(
                url: item.audioCacheURL,
                startPosition: item.playbackPosition,
                rate: playbackSpeed
            )
            audioPlayer.updateNowPlayingInfo(title: item.title)
        } catch {
            print("Playback error: \(error)")
        }
    }

    func generateAndPlay(_ item: NarratorItem) async {
        guard let tts else { return }

        saveCurrentPosition()
        isGenerating = true
        generatingItemID = item.id
        currentItem = item
        showNowPlaying = true

        let voice = VoiceOption.from(identifier: selectedVoice).kittenVoice

        do {
            let result = try await tts.generate(item.content, voice: voice, speed: playbackSpeed)

            try result.writeWAV(to: item.audioCacheURL)
            item.audioDuration = result.duration
            item.voiceIdentifier = selectedVoice
            item.speed = playbackSpeed
            item.playbackPosition = 0

            isGenerating = false
            generatingItemID = nil

            try audioPlayer.play(url: item.audioCacheURL, rate: playbackSpeed)
            audioPlayer.updateNowPlayingInfo(title: item.title)
        } catch {
            isGenerating = false
            generatingItemID = nil
            print("Generation error: \(error)")
        }
    }

    func regenerateCurrentItem() async {
        guard let item = currentItem else { return }
        audioPlayer.stop()
        try? FileManager.default.removeItem(at: item.audioCacheURL)
        await generateAndPlay(item)
    }

    func togglePlayPause() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        audioPlayer.togglePlayPause()
    }

    func skipForward() { audioPlayer.skipForward() }

    func skipBackward() { audioPlayer.skipBackward() }

    func seek(to position: TimeInterval) { audioPlayer.seek(to: position) }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        audioPlayer.setRate(speed)
    }

    func stop() {
        saveCurrentPosition()
        audioPlayer.stop()
        currentItem = nil
    }

    func saveCurrentPosition() {
        guard let item = currentItem, audioPlayer.duration > 0 else { return }
        item.playbackPosition = audioPlayer.currentPosition
    }

    // MARK: - Helpers

    var currentVoice: VoiceOption {
        VoiceOption.from(identifier: selectedVoice)
    }

    private func handlePlaybackFinished() {
        guard let item = currentItem else { return }
        item.isCompleted = true
        item.playbackPosition = 0
    }
}
