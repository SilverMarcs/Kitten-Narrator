import SwiftUI

struct SettingsView: View {
    @Environment(NarratorViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section {
                    heroSection
                }
                .listRowBackground(sectionBackground)

                Section("Default voice") {
                    voiceNavigationRow
                }
                .listRowBackground(sectionBackground)

                Section("Default speed") {
                    speedSlider
                }
                .listRowBackground(sectionBackground)

                Section("About") {
                    aboutCard
                }
                .listRowBackground(sectionBackground)
            }
            .formStyle(.grouped)
            .contentMargins(.top, 15)
            .scrollContentBackground(.hidden)
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
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
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

    // MARK: - Voice

    private var voiceNavigationRow: some View {
        @Bindable var viewModel = viewModel
        let voice = viewModel.currentVoice
        return NavigationLink {
            VoicePickerView(selectedVoice: $viewModel.selectedVoice)
        } label: {
            Label {
                Group {
                    Text(voice.displayName)
                    Text(voice.subtitle)
                }
                .padding(.leading, 5)
            } icon: {
                Circle()
                    .fill(voice.gradient)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text(voice.monogram)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
            }
            .padding(.leading)
        }
    }

    // MARK: - Speed

    private var speedSlider: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { Double(viewModel.playbackSpeed) },
                    set: { viewModel.setSpeed(Float($0)) }
                ),
                in: 0.5...2.0,
                step: 0.25
            ) {
                Text("Playback speed")
            }
            .tint(accent)

            HStack {
                ForEach(Array(stride(from: 0.5, through: 2.0, by: 0.5)), id: \.self) { v in
                    Text(formatSpeed(v))
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    if v < 2.0 { Spacer(minLength: 0) }
                }
            }
        }
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
    }

    private var sectionBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.04)
    }
}
