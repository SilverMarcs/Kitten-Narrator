import SwiftUI

struct MiniPlayerView: View {
    var viewModel: NarratorViewModel
    var namespace: Namespace.ID
    var artworkID: String
    var onTap: () -> Void

    @Environment(\.accent) private var accent

    private var progress: Double {
        guard viewModel.audioPlayer.duration > 0 else { return 0 }
        return viewModel.audioPlayer.currentPosition / viewModel.audioPlayer.duration
    }

    /// Mirror the global selection — the mini player retints along with the
    /// rest of the app when the user switches voices.
    private var voice: VoiceOption {
        viewModel.currentVoice
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // The artwork is the matched transition source.
                artworkTile
                    .matchedTransitionSource(id: artworkID, in: namespace)

                // Title area is tappable to open the full player.
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.currentItem?.title ?? "")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    if viewModel.isGenerating {
                        Text("Generating audio…")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(accent)
                    } else {
                        HStack(spacing: 4) {
                            Text(voice.displayName)
                            Text("·")
                            Text(formatDuration(viewModel.audioPlayer.currentPosition))
                                .monospacedDigit()
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

                // Play / pause
                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(accent)
                        .contentTransition(.symbolEffect(.replace.downUp))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating)

                // Skip forward
                Button {
                    viewModel.skipForward()
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            // Progress ribbon pinned to the bottom edge of the surface.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.15))
                    Capsule()
                        .fill(accent.brandGradient)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.15), value: progress)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .glassEffect(in: .rect(cornerRadius: 22))
    }

    // MARK: - Artwork tile

    private var artworkTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(voice.gradient)

            if viewModel.isGenerating {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Image(systemName: "waveform")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative.reversing,
                                  options: .repeat(.continuous),
                                  isActive: viewModel.audioPlayer.isPlaying)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture { onTap() }
    }
}
