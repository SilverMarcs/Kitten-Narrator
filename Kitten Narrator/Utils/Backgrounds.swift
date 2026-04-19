import SwiftUI

struct AuroraBackground: View {
    @Environment(\.accent) private var accent

    var body: some View {
        ZStack {
            Color.appBackground

            RadialGradient(
                colors: [accent.opacity(0.30), .clear],
                center: .init(x: 0.25, y: 0.18),
                startRadius: 20,
                endRadius: 460
            )

            RadialGradient(
                colors: [accent.mix(with: .white, by: 0.3).opacity(0.25), .clear],
                center: .init(x: 0.85, y: 0.42),
                startRadius: 20,
                endRadius: 420
            )

            RadialGradient(
                colors: [accent.mix(with: .red, by: 0.2).opacity(0.20), .clear],
                center: .init(x: 0.35, y: 0.90),
                startRadius: 20,
                endRadius: 420
            )
        }
        .animation(.smooth(duration: 0.8), value: accent)
    }
}

struct VoiceBackdrop: View {
    let color: Color

    var body: some View {
        ZStack {
            Color.appBackground

            RadialGradient(
                colors: [color.opacity(0.40), .clear],
                center: .init(x: 0.25, y: 0.15),
                startRadius: 20,
                endRadius: 420
            )

            RadialGradient(
                colors: [color.opacity(0.22), .clear],
                center: .init(x: 0.80, y: 0.85),
                startRadius: 20,
                endRadius: 420
            )
        }
        .animation(.smooth(duration: 0.8), value: color)
    }
}
