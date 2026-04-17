import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: NarratorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroSection
                        .padding(.horizontal, 20)

                    sectionLabel("Default voice")
                    voiceNavigationRow
                        .padding(.horizontal, 20)

                    sectionLabel("Default speed")
                    speedSlider
                        .padding(.horizontal, 20)

                    sectionLabel("About")
                    aboutCard
                        .padding(.horizontal, 20)

                    Color.clear.frame(height: 20)
                }
                .padding(.top, 8)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(
                LinearGradient(
                    colors: [accent.opacity(0.08), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accent.brandGradient)
                    .frame(width: 62, height: 62)
                    .shadow(color: accent.opacity(0.4), radius: 14, y: 6)

                Image(systemName: "waveform")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Narrator preferences")
                    .font(.headline)
                Text("Tweak your default voice and\nplayback speed for new narrations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Voice navigation (uses a plain NavigationLink so the tap is reliable)

    private var voiceNavigationRow: some View {
        NavigationLink {
            VoicePickerView(selectedVoice: $viewModel.selectedVoice)
        } label: {
            voiceRowContent
        }
        .buttonStyle(.plain)
    }

    private var voiceRowContent: some View {
        let voice = viewModel.currentVoice
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(voice.gradient)
                    .frame(width: 46, height: 46)
                Text(voice.monogram)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(voice.displayName)
                    .font(.callout.weight(.semibold))
                Text(voice.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Speed slider

    private var speedSlider: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Playback speed")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatSpeed(Double(viewModel.playbackSpeed)))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(accent)
                    .contentTransition(.numericText())
            }

            Slider(
                value: Binding(
                    get: { Double(viewModel.playbackSpeed) },
                    set: { viewModel.setSpeed(Float($0)) }
                ),
                in: 0.5...2.0,
                step: 0.25
            ) {
                Text("Playback speed")
            } minimumValueLabel: {
                Text("0.5×")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("2×")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .tint(accent)

            // Tick marks, just for a visual anchor
            HStack {
                ForEach(Array(stride(from: 0.5, through: 2.0, by: 0.25)), id: \.self) { v in
                    Text(formatSpeed(v))
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(
                            abs(Double(viewModel.playbackSpeed) - v) < 0.01
                            ? accent
                            : .secondary.opacity(0.7)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
                Text("Private by design")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            Text("Everything — the speech engine, the text, the generated audio — lives on this device. Nothing is sent to a server.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 24)
            .padding(.top, 4)
    }
}
