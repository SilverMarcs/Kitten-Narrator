import SwiftUI

struct PlayerDockView: View {
    @Binding var showLyrics: Bool
    @Environment(NarratorViewModel.self) private var viewModel
    @Environment(\.accent) private var accent

    @State private var isDragging = false
    @State private var dragPosition: TimeInterval = 0

    private var voice: VoiceOption {
        viewModel.currentVoice
    }

    private var displayedPosition: TimeInterval {
        isDragging ? dragPosition : viewModel.audioPlayer.currentPosition
    }

    var body: some View {
        VStack(spacing: 14) {
            if !viewModel.audioPlayer.isStreamingGeneration {
                progressSection
                    .transition(.opacity)
            }
            
            controlsSection
            
            Spacer(minLength: 0)
    
            Color.clear
                .frame(height: 7.5)
        
            actionRow
        }
        .animation(.smooth, value: viewModel.audioPlayer.isStreamingGeneration)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { displayedPosition },
                    set: { newValue in
                        if !isDragging { isDragging = true }
                        dragPosition = newValue
                    }
                ),
                in: 0...max(viewModel.audioPlayer.duration, 0.01),
                onEditingChanged: { editing in
                    if !editing {
                        viewModel.seek(to: dragPosition)
                        isDragging = false
                    }
                }
            )
            .disabled(viewModel.isGenerating)

            HStack {
                Text(formatDuration(displayedPosition))
                Spacer()
                let remaining = max(0, viewModel.audioPlayer.duration - displayedPosition)
                Text("-\(formatDuration(remaining))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 18) {
                skipButton(icon: "gobackward.15", accessibility: "Back 15 seconds") {
                    viewModel.skipBackward()
                }

                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 34, weight: .bold))
                        .contentTransition(.symbolEffect(.replace.downUp))
                        .padding(15)
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isGenerating)
                .accessibilityLabel(viewModel.audioPlayer.isPlaying ? "Pause" : "Play")

                skipButton(icon: "goforward.15", accessibility: "Forward 15 seconds") {
                    viewModel.skipForward()
                }
            }
        }
    }

    private func skipButton(icon: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(viewModel.isGenerating || viewModel.audioPlayer.isStreamingGeneration)
        .accessibilityLabel(accessibility)
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 0) {
            speedChip

            Spacer(minLength: 0)

            voiceChip
        }
        .overlay {
            transcriptChip
        }
        .frame(maxWidth: 400)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }

    private var speedChip: some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                Button {
                    viewModel.setSpeed(Float(speed))
                } label: {
                    HStack {
                        Text(formatSpeed(speed))
                        if abs(Double(viewModel.playbackSpeed) - speed) < 0.01 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(formatSpeed(Double(viewModel.playbackSpeed)))
                .font(.footnote.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .frame(width: 52, height: 38)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("Playback speed")
    }

    private var transcriptChip: some View {
        Button {
            withAnimation(.smooth) { showLyrics.toggle() }
        } label: {
            Image(systemName: "quote.bubble")
                .font(.footnote.weight(.bold))
                .foregroundStyle(showLyrics ? .white : .primary)
                .frame(width: 52, height: 38)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(
            showLyrics
            ? .regular.tint(accent.opacity(0.85)).interactive()
            : .regular.interactive(),
            in: .capsule
        )
        .accessibilityLabel(showLyrics ? "Hide transcript" : "Show transcript")
    }

    private var voiceChip: some View {
        @Bindable var viewModel = viewModel
        return NavigationLink {
            VoicePickerView(selectedVoice: $viewModel.selectedVoice)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.wave.2.fill")
                    .font(.footnote.weight(.bold))
                Text(voice.displayName)
                    .font(.footnote.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(voice.color.opacity(0.35)).interactive(), in: .capsule)
    }
}
