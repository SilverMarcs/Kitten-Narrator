import SwiftUI

struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Color.appBackground

            RadialGradient(
                colors: [Brand.primary.opacity(0.30), .clear],
                center: .init(x: 0.25, y: 0.18),
                startRadius: 20,
                endRadius: 460
            )

            RadialGradient(
                colors: [Color(red: 1.0, green: 0.68, blue: 0.35).opacity(0.25), .clear],
                center: .init(x: 0.85, y: 0.42),
                startRadius: 20,
                endRadius: 420
            )

            RadialGradient(
                colors: [Color(red: 0.95, green: 0.40, blue: 0.30).opacity(0.20), .clear],
                center: .init(x: 0.35, y: 0.90),
                startRadius: 20,
                endRadius: 420
            )
        }
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
