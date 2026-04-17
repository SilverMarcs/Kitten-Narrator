import SwiftUI

// MARK: - Dynamic accent via Environment
//
// The app's accent color follows the selected voice. Every view reads the
// accent from the environment (or implicitly through `.tint`) rather than
// hard-coding an orange brand color.

extension EnvironmentValues {
    /// The voice-derived accent color for the current session. Defaults to
    /// Bella's coral until the view hierarchy overrides it.
    @Entry var accent: Color = Color(red: 0.98, green: 0.50, blue: 0.25)
}

// MARK: - Color helpers

extension Color {
    /// A three-stop diagonal gradient derived from this color.
    var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                self.mix(with: .white, by: 0.18),
                self,
                self.mix(with: .black, by: 0.12),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A soft surface wash derived from this color — for cards & backdrops.
    var softSurface: LinearGradient {
        LinearGradient(
            colors: [self.opacity(0.18), self.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Cross-platform backgrounds

extension Color {
    static var appBackground: Color {
        #if os(iOS) || os(visionOS) || os(tvOS)
        return Color(uiColor: .systemBackground)
        #elseif os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return .black
        #endif
    }

    static var appSecondaryBackground: Color {
        #if os(iOS) || os(visionOS) || os(tvOS)
        return Color(uiColor: .secondarySystemBackground)
        #elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return .gray.opacity(0.2)
        #endif
    }
}

// MARK: - Voice palette

extension VoiceOption {
    /// Solid color derived from the voice's personality.
    var color: Color {
        Color(red: iconColor.red, green: iconColor.green, blue: iconColor.blue)
    }

    /// Voice-tinted gradient for artwork.
    var gradient: LinearGradient { color.brandGradient }

    /// The single letter used on the round avatar.
    var monogram: String { String(displayName.prefix(1)) }
}

// MARK: - Format helpers

func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

func formatSpeed(_ speed: Double) -> String {
    if abs(speed - floor(speed)) < 0.001 { return "\(Int(speed))×" }
    return String(format: "%.2g×", speed)
}

// MARK: - Legacy Brand namespace
//
// Used only on the pre-library screens (download, loading, error) where no
// voice has been chosen yet. Inside the app proper, use `\.accent` instead.

enum Brand {
    static let primary = Color(red: 0.98, green: 0.50, blue: 0.25)
    static var gradient: LinearGradient { primary.brandGradient }
    static var softSurface: LinearGradient { primary.softSurface }
}

// MARK: - Waveform art (retained for future reuse; not currently rendered)

/// Decorative waveform bar drawing. Kept around so we can swap it back in
/// once we adopt a proper audio-reactive waveform package.
struct WaveformArt: View {
    var voice: VoiceOption
    var isActive: Bool
    var isGenerating: Bool

    private let barCount = 16
    private let baseHeights: [CGFloat]

    init(voice: VoiceOption, isActive: Bool, isGenerating: Bool) {
        self.voice = voice
        self.isActive = isActive
        self.isGenerating = isGenerating
        var rng = SeededRandom(seed: UInt64(voice.rawValue.hashValue & 0xFFFF))
        self.baseHeights = (0..<16).map { _ in CGFloat.random(in: 0.35...1.0, using: &rng) }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/18, paused: !isActive && !isGenerating)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas(opaque: false) { ctx, size in
                let barWidth: CGFloat = 6
                let gap: CGFloat = (size.width - (CGFloat(barCount) * barWidth)) / CGFloat(max(barCount - 1, 1))
                let midY = size.height / 2

                for i in 0..<barCount {
                    let phase = Double(i) * 0.45
                    let pulse = isActive || isGenerating
                        ? (sin(t * 2.2 + phase) * 0.5 + 0.5)
                        : 0.5
                    let scale = CGFloat(0.55 + pulse * 0.45)
                    let barHeight = max(barWidth, size.height * 0.82 * baseHeights[i] * scale)
                    let x = CGFloat(i) * (barWidth + gap)
                    let rect = CGRect(x: x, y: midY - barHeight / 2,
                                      width: barWidth, height: barHeight)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                    ctx.fill(path, with: .color(.white.opacity(0.95)))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 56)
        }
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}
