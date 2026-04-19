import AVFoundation
import KittenTTS

@Observable
final class VoicePreviewService {

    private var tts: KittenTTS?
    private var player: AVAudioPlayer?
    private var cacheDir: URL
    private var generatingVoices: Set<String> = []

    private static let previewPhrases = [
        "Here's how I sound.",
        "Nice to meet you!",
        "Let me read that for you.",
        "Ready when you are.",
        "How does this sound?",
        "I'll be your narrator.",
        "Let's get started.",
        "Sounds good to me!",
    ]

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = caches.appendingPathComponent("voice_previews", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func setTTS(_ tts: KittenTTS?) {
        self.tts = tts
    }

    // MARK: - Preview

    func playPreview(for voice: VoiceOption) async {
        let phraseIndex = Int.random(in: 0..<Self.previewPhrases.count)
        let url = cacheURL(for: voice, phraseIndex: phraseIndex)

        if FileManager.default.fileExists(atPath: url.path) {
            playFile(at: url)
            return
        }

        guard let tts, !generatingVoices.contains(voice.rawValue) else { return }
        generatingVoices.insert(voice.rawValue)

        do {
            let result = try await tts.generate(
                Self.previewPhrases[phraseIndex],
                voice: voice.kittenVoice,
                speed: 1.0
            )
            try result.wavData().write(to: url, options: .atomic)
            generatingVoices.remove(voice.rawValue)
            playFile(at: url)
        } catch {
            generatingVoices.remove(voice.rawValue)
        }
    }

    func precacheAll() async {
        guard let tts else { return }
        for voice in VoiceOption.allCases {
            for (i, phrase) in Self.previewPhrases.enumerated() {
                let url = cacheURL(for: voice, phraseIndex: i)
                guard !FileManager.default.fileExists(atPath: url.path) else { continue }
                do {
                    let result = try await tts.generate(phrase, voice: voice.kittenVoice, speed: 1.0)
                    try result.wavData().write(to: url, options: .atomic)
                } catch {}
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    // MARK: - Private

    private func cacheURL(for voice: VoiceOption, phraseIndex: Int) -> URL {
        cacheDir.appendingPathComponent("\(voice.rawValue)_preview_\(phraseIndex).wav")
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
