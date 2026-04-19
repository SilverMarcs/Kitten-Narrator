import AVFoundation
import KittenTTS

@Observable
final class VoicePreviewService {

    private var tts: KittenTTS?
    private var player: AVAudioPlayer?
    private var cacheDir: URL
    private var generatingVoices: Set<String> = []

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = caches.appendingPathComponent("voice_previews", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func setTTS(_ tts: KittenTTS?) {
        self.tts = tts
    }

    // MARK: - Preview

    private static let previewText = "Here's a quick preview of my voice."

    func playPreview(for voice: VoiceOption) async {
        let url = cacheURL(for: voice)

        if FileManager.default.fileExists(atPath: url.path) {
            playFile(at: url)
            return
        }

        guard let tts, !generatingVoices.contains(voice.rawValue) else { return }
        generatingVoices.insert(voice.rawValue)

        do {
            var allSamples: [Float] = []
            let stream = await tts.generateStreaming(
                Self.previewText,
                voice: voice.kittenVoice,
                speed: 1.0
            )
            for try await chunk in stream {
                allSamples.append(contentsOf: chunk.samples)
            }
            let wav = NarratorViewModel.encodeWAV(samples: allSamples, sampleRate: 24_000)
            try wav.write(to: url, options: .atomic)
            generatingVoices.remove(voice.rawValue)
            playFile(at: url)
        } catch {
            generatingVoices.remove(voice.rawValue)
        }
    }

    func precacheAll() async {
        guard let tts else { return }
        for voice in VoiceOption.allCases {
            let url = cacheURL(for: voice)
            guard !FileManager.default.fileExists(atPath: url.path) else { continue }
            guard !generatingVoices.contains(voice.rawValue) else { continue }
            generatingVoices.insert(voice.rawValue)
            do {
                var allSamples: [Float] = []
                let stream = await tts.generateStreaming(
                    Self.previewText,
                    voice: voice.kittenVoice,
                    speed: 1.0
                )
                for try await chunk in stream {
                    allSamples.append(contentsOf: chunk.samples)
                }
                let wav = NarratorViewModel.encodeWAV(samples: allSamples, sampleRate: 24_000)
                try wav.write(to: url, options: .atomic)
            } catch {}
            generatingVoices.remove(voice.rawValue)
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    // MARK: - Private

    private func cacheURL(for voice: VoiceOption) -> URL {
        cacheDir.appendingPathComponent("\(voice.rawValue)_preview.wav")
    }

    private func playFile(at url: URL) {
        stop()
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        #endif
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.45
        player?.prepareToPlay()
        player?.play()
    }
}
