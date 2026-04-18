import SwiftUI

struct NowPlayingView: View {
    @Bindable var viewModel: NarratorViewModel
    var namespace: Namespace.ID
    var artworkID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    @State private var isDragging = false
    @State private var dragPosition: TimeInterval = 0
    @State private var showLyrics = true

    /// The visible voice mirrors the global selection (the same value the
    /// Settings picker edits). This way switching voices here instantly
    /// retints the whole app, and the chip here always agrees with Settings.
    private var voice: VoiceOption {
        viewModel.currentVoice
    }

    private var displayedPosition: TimeInterval {
        isDragging ? dragPosition : viewModel.audioPlayer.currentPosition
    }

    var body: some View {
        VStack(spacing: 0) {
            if showLyrics {
                transcriptStage
                    .transition(.opacity)
            } else {
                artworkStage
                    .transition(.opacity)
            }

            playerDock
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            dragHandle
                .padding(.top, 6)
                .padding(.bottom, 4)
        }
        .background {
            VoiceBackdrop(color: voice.color)
                .ignoresSafeArea()
        }
        .onDisappear { viewModel.saveCurrentPosition() }
    }

    // MARK: - Drag handle

    private var dragHandle: some View {
        Capsule()
            .fill(.secondary.opacity(0.4))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    // MARK: - Artwork stage

    private var artworkStage: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            artwork
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)

            titleSection
                .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(voice.gradient)
                .shadow(color: voice.color.opacity(0.45), radius: 40, y: 20)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            if viewModel.isGenerating {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("Generating audio…")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 92, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .symbolEffect(.variableColor.iterative.reversing,
                                  options: .repeat(.continuous),
                                  isActive: viewModel.audioPlayer.isPlaying)
            }
        }
    }

    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(viewModel.currentItem?.title ?? "Untitled")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(voice.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(accent)
        }
    }

    // MARK: - Transcript stage

    private var transcriptStage: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(voice.gradient)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentItem?.title ?? "Untitled")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(voice.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)

            transcriptScroll
                .padding(.horizontal, 16)
        }
    }

    private var transcriptScroll: some View {
        let words = (viewModel.currentItem?.content ?? "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let activeIndex = viewModel.currentWordIndex

        return ScrollViewReader { proxy in
            ScrollView {
                FlowLayout(horizontalSpacing: 6, verticalSpacing: 10) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        Text(word)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(wordColor(at: index, activeIndex: activeIndex))
                            .id(index)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.95),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .onChange(of: activeIndex) {
                withAnimation(.smooth(duration: 0.35)) {
                    proxy.scrollTo(activeIndex, anchor: .center)
                }
            }
        }
    }

    private func wordColor(at index: Int, activeIndex: Int) -> Color {
        if index == activeIndex { return accent }
        return index < activeIndex
            ? Color.primary.opacity(0.35)
            : Color.primary.opacity(0.85)
    }

    // MARK: - Dock

    private var playerDock: some View {
        VStack(spacing: 14) {
            if !viewModel.audioPlayer.isStreamingGeneration {
                progressSection
                    .transition(.opacity)
            }
            controlsSection
            actionRow
        }
        .animation(.smooth, value: viewModel.audioPlayer.isStreamingGeneration)
    }

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

    // MARK: - Action row (speed, transcript centered, voice)

    private var actionRow: some View {
        // Use a flanking HStack (speed left, voice right) and overlay the
        // transcript button as a dead-centered floating chip so its position
        // is not affected by the varying width of the voice name.
        HStack(spacing: 0) {
            speedChip

            Spacer(minLength: 0)

            voiceChip
        }
        .overlay {
            transcriptChip
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
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
        NavigationLink {
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

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 0
    var verticalSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            lineHeight = max(lineHeight, size.height)
            x += size.width + horizontalSpacing
            totalWidth = max(totalWidth, x)
        }

        return (CGSize(width: totalWidth, height: y + lineHeight), frames)
    }
}

// MARK: - Voice-tinted backdrop (static)

private struct VoiceBackdrop: View {
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
