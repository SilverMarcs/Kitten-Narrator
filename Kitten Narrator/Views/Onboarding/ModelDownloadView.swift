import SwiftUI

struct ModelDownloadView: View {
    let progress: Double

    @State private var appear = false

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 36) {
                    Spacer(minLength: 40)

                    heroMark
                        .scaleEffect(appear ? 1 : 0.8)
                        .opacity(appear ? 1 : 0)

                    VStack(spacing: 12) {
                        Text("Kitten Narrator")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Turn anything you read into\naudio you can listen to anywhere.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)

                    featureRow
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 16)

                    Spacer(minLength: 20)

                    progressCard
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            withAnimation(.smooth(duration: 0.9, extraBounce: 0.1)) {
                appear = true
            }
        }
    }

    // MARK: - Hero

    private var heroMark: some View {
        ZStack {
            Circle()
                .stroke(Brand.primary.opacity(0.12), lineWidth: 1)
                .frame(width: 220, height: 220)

            ForEach(0..<3) { i in
                Circle()
                    .fill(Brand.primary.opacity(0.10))
                    .frame(width: 140 + CGFloat(i) * 28, height: 140 + CGFloat(i) * 28)
                    .blur(radius: CGFloat(i) * 4)
            }

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 128, height: 128)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Brand.primary.opacity(0.35), radius: 24, y: 12)

            Image(systemName: "waveform")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Brand.gradient)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeat(.continuous))
        }
        .frame(height: 240)
    }

    // MARK: - Features

    private var featureRow: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                FeaturePill(icon: "text.alignleft", label: "Any text")
                FeaturePill(icon: "link", label: "Web pages")
                FeaturePill(icon: "person.wave.2", label: "8 voices")
            }
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: progress >= 0.999 ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.title3)
                    .foregroundStyle(Brand.primary)
                    .contentTransition(.symbolEffect(.replace))

                Text(progress >= 0.999 ? "Getting ready..." : "Installing the speech engine")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.linear, value: progress)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .overlay(
                            Capsule().stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                    Capsule()
                        .fill(Brand.gradient)
                        .frame(width: max(6, geo.size.width * progress))
                        .shadow(color: Brand.primary.opacity(0.55), radius: 10, y: 0)
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 8)

            Text("This one-time download is around 50 MB.\nEverything stays on your device.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

// MARK: - Feature pill

private struct FeaturePill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(Brand.primary)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}
