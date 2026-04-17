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

    /// Word-level timestamps from the TTS model's predicted phoneme durations.
    /// Built incrementally during streaming; each sentence's timings are offset
    /// by the cumulative audio time of prior sentences.
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

        // No real word timings for cached replay — currentWordIndex
        // falls back to character-weighted interpolation.
        wordTimings = []

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
        let sentences = Self.splitIntoSentences(item.content)

        do {
            wordTimings = []
            var cumulativeWordIndex = 0
            var cumulativeAudioTime: Double = 0

            try audioPlayer.beginStreaming(sampleRate: 24_000)
            audioPlayer.updateNowPlayingInfo(title: item.title)

            var firstChunk = true
            for sentence in sentences {
                // Bail out if the user switched to a different item.
                guard currentItem?.id == item.id else { return }

                let result = try await tts.generate(sentence, voice: voice, speed: playbackSpeed)
                audioPlayer.appendAudio(result.samples)

                let sentenceWords = sentence
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                let chunkDuration = Double(result.samples.count) / 24_000

                if !result.wordTimings.isEmpty {
                    // Use real timestamps from the model's duration output,
                    // capping to the original word count to avoid index mismatches
                    // caused by text preprocessing expanding words.
                    let count = min(result.wordTimings.count, sentenceWords.count)
                    for j in 0..<count {
                        let wt = result.wordTimings[j]
                        wordTimings.append(KittenWordTiming(
                            wordIndex: cumulativeWordIndex + j,
                            word: sentenceWords[j],
                            startTime: cumulativeAudioTime + wt.startTime,
                            endTime: cumulativeAudioTime + wt.endTime
                        ))
                    }
                } else {
                    // Fallback: synthesise character-weighted timings when the
                    // model doesn't provide duration data.
                    let charCounts = sentenceWords.map { $0.count }
                    let totalChars = max(charCounts.reduce(0, +), 1)
                    var elapsed: Double = 0
                    for (j, word) in sentenceWords.enumerated() {
                        let share = chunkDuration * Double(word.count) / Double(totalChars)
                        wordTimings.append(KittenWordTiming(
                            wordIndex: cumulativeWordIndex + j,
                            word: word,
                            startTime: cumulativeAudioTime + elapsed,
                            endTime: cumulativeAudioTime + elapsed + share
                        ))
                        elapsed += share
                    }
                }

                cumulativeWordIndex += sentenceWords.count
                cumulativeAudioTime += chunkDuration

                if firstChunk {
                    firstChunk = false
                    isGenerating = false
                    generatingItemID = nil
                }
            }

            guard currentItem?.id == item.id else { return }

            // Cache the complete audio as WAV for future replay.
            let samples = audioPlayer.accumulatedSamples
            let wavData = Self.encodeWAV(samples: samples, sampleRate: 24_000)
            try wavData.write(to: item.audioCacheURL, options: .atomic)
            item.audioDuration = Double(samples.count) / 24_000
            item.voiceIdentifier = selectedVoice
            item.speed = playbackSpeed
            item.playbackPosition = 0

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

    // MARK: - Word Tracking

    /// Index of the word currently being spoken.
    ///
    /// When real word timestamps are available (from the model's predicted
    /// phoneme durations), this performs a direct time-based lookup. Otherwise
    /// falls back to character-weighted linear interpolation.
    var currentWordIndex: Int {
        guard let item = currentItem else { return 0 }
        let pos = audioPlayer.currentPosition

        // Prefer real timestamps from the TTS duration output.
        if !wordTimings.isEmpty {
            // Find the last word whose startTime <= pos.
            var best = 0
            for (i, wt) in wordTimings.enumerated() {
                if wt.startTime <= pos { best = i } else { break }
            }
            return wordTimings[best].wordIndex
        }

        // Fallback: character-weighted interpolation for cached replay.
        guard audioPlayer.duration > 0 else { return 0 }
        let words = item.content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return 0 }
        let progress = pos / audioPlayer.duration
        let charCounts = words.map { $0.count }
        let totalChars = charCounts.reduce(0, +)
        guard totalChars > 0 else {
            return min(Int(progress * Double(words.count)), words.count - 1)
        }
        let targetChars = progress * Double(totalChars)
        var accumulated = 0
        for i in 0..<words.count {
            accumulated += charCounts[i]
            if Double(accumulated) >= targetChars { return i }
        }
        return words.count - 1
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

    // MARK: - Sentence Splitting

    /// Split text into sentence-sized chunks for progressive TTS generation.
    static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if ".!?".contains(char) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }

        let remaining = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            if sentences.isEmpty {
                sentences.append(remaining)
            } else {
                sentences[sentences.count - 1] += " " + remaining
            }
        }

        // Merge very short sentences so each chunk has enough text for
        // natural-sounding TTS output.
        var merged: [String] = []
        var buffer = ""
        for sentence in sentences {
            buffer += (buffer.isEmpty ? "" : " ") + sentence
            if buffer.count >= 80 {
                merged.append(buffer)
                buffer = ""
            }
        }
        if !buffer.isEmpty {
            if merged.isEmpty {
                merged.append(buffer)
            } else {
                merged[merged.count - 1] += " " + buffer
            }
        }

        return merged.isEmpty ? [text] : merged
    }

    // MARK: - WAV Encoder

    /// Encode Float32 samples as a 16-bit PCM WAV file.
    static func encodeWAV(samples: [Float], sampleRate: Int) -> Data {
        let bitsPerSample = 16
        let blockAlign = bitsPerSample / 8
        let dataSize = samples.count * blockAlign
        let fileSize = 36 + dataSize

        var d = Data(capacity: 44 + dataSize)

        func append32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func append16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }

        // RIFF header
        d.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        append32(UInt32(fileSize))
        d.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        d.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        append32(16)
        append16(1)                                      // PCM
        append16(1)                                      // mono
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * blockAlign))
        append16(UInt16(blockAlign))
        append16(UInt16(bitsPerSample))

        // data chunk
        d.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        append32(UInt32(dataSize))

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * 32767)
            withUnsafeBytes(of: int16.littleEndian) { d.append(contentsOf: $0) }
        }

        return d
    }
}
