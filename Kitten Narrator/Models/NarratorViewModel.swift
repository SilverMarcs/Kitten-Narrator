import Foundation
import KittenTTS
import SwiftUI

extension KittenWordTiming: Codable {
    enum CodingKeys: String, CodingKey {
        case wordIndex, word, startTime, endTime
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            wordIndex: try c.decode(Int.self, forKey: .wordIndex),
            word: try c.decode(String.self, forKey: .word),
            startTime: try c.decode(Double.self, forKey: .startTime),
            endTime: try c.decode(Double.self, forKey: .endTime)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(wordIndex, forKey: .wordIndex)
        try c.encode(word, forKey: .word)
        try c.encode(startTime, forKey: .startTime)
        try c.encode(endTime, forKey: .endTime)
    }
}

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

    var wordTimings: [KittenWordTiming] = []

    // MARK: - Settings

    var selectedVoice: String {
        didSet { UserDefaults.standard.set(selectedVoice, forKey: "narrator_voice") }
    }

    var playbackSpeed: Float {
        didSet { UserDefaults.standard.set(playbackSpeed, forKey: "narrator_speed") }
    }

    // MARK: - Services

    let audioPlayer = AudioPlayerService()
    let voicePreview = VoicePreviewService()
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
            voicePreview.setTTS(tts)
            audioPlayer.setupRemoteCommands()
            audioPlayer.onPlaybackFinished = { [weak self] in
                self?.handlePlaybackFinished()
            }
            Task { await voicePreview.precacheAll() }
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

        // Load cached word timings for highlight sync
        if let data = try? Data(contentsOf: item.wordTimingsCacheURL),
           let cached = try? JSONDecoder().decode([KittenWordTiming].self, from: data) {
            wordTimings = cached
        } else {
            wordTimings = []
        }

        do {
            try audioPlayer.play(
                url: item.audioCacheURL,
                startPosition: item.playbackPosition,
                rate: playbackSpeed
            )
            audioPlayer.updateNowPlayingInfo(title: item.title, artworkURL: item.artworkURL.flatMap(URL.init(string:)))
        } catch {
            print("Playback error: \(error)")
        }
    }

    func generateAndPlay(_ item: NarratorItem, autoPlay: Bool = true) async {
        guard let tts else { return }

        saveCurrentPosition()
        isGenerating = true
        generatingItemID = item.id
        currentItem = item
        showNowPlaying = true

        let voice = VoiceOption.from(identifier: selectedVoice).kittenVoice

        do {
            wordTimings = []
            var cumulativeWordIndex = 0
            var cumulativeAudioTime: Double = 0

            try audioPlayer.beginStreaming(sampleRate: 24_000, autoPlay: autoPlay)
            audioPlayer.updateNowPlayingInfo(title: item.title, artworkURL: item.artworkURL.flatMap(URL.init(string:)))

            var firstChunk = true
            let stream = await tts.generateStreaming(item.content, voice: voice, speed: playbackSpeed)

            for try await chunk in stream {
                guard currentItem?.id == item.id else { return }

                audioPlayer.appendAudio(chunk.samples)

                let chunkWords = chunk.inputText
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }

                if !chunk.wordTimings.isEmpty {
                    let count = min(chunk.wordTimings.count, chunkWords.count)
                    for j in 0..<count {
                        let wt = chunk.wordTimings[j]
                        wordTimings.append(KittenWordTiming(
                            wordIndex: cumulativeWordIndex + j,
                            word: chunkWords[j],
                            startTime: cumulativeAudioTime + wt.startTime,
                            endTime: cumulativeAudioTime + wt.endTime
                        ))
                    }
                } else {
                    let charCounts = chunkWords.map { $0.count }
                    let totalChars = max(charCounts.reduce(0, +), 1)
                    var elapsed: Double = 0
                    for (j, word) in chunkWords.enumerated() {
                        let share = chunk.duration * Double(word.count) / Double(totalChars)
                        wordTimings.append(KittenWordTiming(
                            wordIndex: cumulativeWordIndex + j,
                            word: word,
                            startTime: cumulativeAudioTime + elapsed,
                            endTime: cumulativeAudioTime + elapsed + share
                        ))
                        elapsed += share
                    }
                }

                cumulativeWordIndex += chunkWords.count
                cumulativeAudioTime += chunk.duration

                if firstChunk {
                    firstChunk = false
                    isGenerating = false
                    generatingItemID = nil
                }
            }

            guard currentItem?.id == item.id else { return }

            let samples = audioPlayer.accumulatedSamples
            let wavData = Self.encodeWAV(samples: samples, sampleRate: 24_000)
            try wavData.write(to: item.audioCacheURL, options: .atomic)
            item.audioDuration = Double(samples.count) / 24_000
            item.voiceIdentifier = selectedVoice
            item.speed = playbackSpeed
            item.playbackPosition = 0

            // Calibrate word timings: scale to match actual audio duration
            // so predicted timings don't drift from the real waveform.
            if !wordTimings.isEmpty, let lastEnd = wordTimings.last?.endTime, lastEnd > 0 {
                let actualDuration = Double(samples.count) / 24_000
                let scale = actualDuration / lastEnd
                if abs(scale - 1.0) > 0.001 {
                    wordTimings = wordTimings.map {
                        KittenWordTiming(
                            wordIndex: $0.wordIndex,
                            word: $0.word,
                            startTime: $0.startTime * scale,
                            endTime: $0.endTime * scale
                        )
                    }
                }
            }

            // Persist word timings for cached playback
            if let data = try? JSONEncoder().encode(wordTimings) {
                try? data.write(to: item.wordTimingsCacheURL, options: .atomic)
            }

            audioPlayer.finishStreaming()
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
        try? FileManager.default.removeItem(at: item.wordTimingsCacheURL)
        await generateAndPlay(item)
    }

    func swapVoice() async {
        guard let item = currentItem else { return }
        audioPlayer.stop()
        try? FileManager.default.removeItem(at: item.audioCacheURL)
        try? FileManager.default.removeItem(at: item.wordTimingsCacheURL)
        item.voiceIdentifier = selectedVoice
        item.playbackPosition = 0
        await generateAndPlay(item, autoPlay: false)
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

    // MARK: - Word Tracking

    var currentWordIndex: Int {
        guard currentItem != nil else { return 0 }
        let pos = audioPlayer.currentPosition

        guard !wordTimings.isEmpty else { return 0 }

        // Binary search: find last word whose startTime <= pos
        var lo = 0
        var hi = wordTimings.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if wordTimings[mid].startTime <= pos {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return wordTimings[lo].wordIndex
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

    // MARK: - WAV Encoder

    static func encodeWAV(samples: [Float], sampleRate: Int) -> Data {
        let bitsPerSample = 16
        let blockAlign = bitsPerSample / 8
        let dataSize = samples.count * blockAlign
        let fileSize = 36 + dataSize

        var d = Data(capacity: 44 + dataSize)

        func append32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func append16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }

        d.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        append32(UInt32(fileSize))
        d.append(contentsOf: [0x57, 0x41, 0x56, 0x45])

        d.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        append32(16)
        append16(1)
        append16(1)
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * blockAlign))
        append16(UInt16(blockAlign))
        append16(UInt16(bitsPerSample))

        d.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        append32(UInt32(dataSize))

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * 32767)
            withUnsafeBytes(of: int16.littleEndian) { d.append(contentsOf: $0) }
        }

        return d
    }
}
