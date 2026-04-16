import SwiftUI

struct NowPlayingView: View {
    @Bindable var viewModel: NarratorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isDragging = false
    @State private var dragPosition: TimeInterval = 0

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 28) {
                    artworkView
                        .padding(.horizontal, 48)
                        .padding(.top, 20)

                    titleSection
                        .padding(.horizontal, 32)

                    progressSection
                        .padding(.horizontal, 32)

                    controlsSection

                    bottomControls
                        .padding(.horizontal, 28)
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(backgroundGradient)
        .onDisappear {
            viewModel.saveCurrentPosition()
        }
    }

    // MARK: - Artwork

    private var artworkView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.2),
                            Color.orange.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: .orange.opacity(0.15), radius: 24, y: 12)

            if viewModel.isGenerating {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.8)
                        .tint(.orange)

                    Text("Generating audio...")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "waveform")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(.orange)
                        .symbolEffect(.variableColor.iterative.reversing, isActive: viewModel.audioPlayer.isPlaying)

                    // Text preview
                    if let content = viewModel.currentItem?.content {
                        Text(content.prefix(200))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(5)
                            .padding(.horizontal, 32)
                    }
                }
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 6) {
            Text(viewModel.currentItem?.title ?? "Untitled")
                .font(.title3.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Text(viewModel.currentVoice.displayName)
                Circle().fill(.secondary).frame(width: 3, height: 3)
                Text(speedLabel)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { isDragging ? dragPosition : viewModel.audioPlayer.currentPosition },
                    set: { newValue in
                        isDragging = true
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
            .tint(.orange)
            .disabled(viewModel.isGenerating)

            HStack {
                Text(formatTime(isDragging ? dragPosition : viewModel.audioPlayer.currentPosition))
                Spacer()
                let remaining = max(0, viewModel.audioPlayer.duration - (isDragging ? dragPosition : viewModel.audioPlayer.currentPosition))
                Text("-\(formatTime(remaining))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: 44) {
            Button { viewModel.skipBackward() } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2)
            }
            .disabled(viewModel.isGenerating)

            Button { viewModel.togglePlayPause() } label: {
                ZStack {
                    Circle()
                        .fill(.orange)
                        .frame(width: 72, height: 72)

                    Image(systemName: viewModel.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
            .disabled(viewModel.isGenerating)

            Button { viewModel.skipForward() } label: {
                Image(systemName: "goforward.15")
                    .font(.title2)
            }
            .disabled(viewModel.isGenerating)
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack {
            // Speed control
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
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            // Regenerate
            if viewModel.currentItem?.hasGeneratedAudio == true && !viewModel.isGenerating {
                Button {
                    Task { await viewModel.regenerateCurrentItem() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }

            Spacer()

            // Voice picker
            NavigationLink {
                VoicePickerView(selectedVoice: $viewModel.selectedVoice)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.wave.2")
                    Text(viewModel.currentVoice.displayName)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(white: 1.0, opacity: 0.001),
                Color.orange.opacity(0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Helpers

    private var speedLabel: String {
        let speed = viewModel.playbackSpeed
        if abs(speed - 1.0) < 0.01 { return "Normal" }
        return formatSpeed(Double(speed))
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return "\(Int(speed))x"
        }
        return String(format: "%.2gx", speed)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
