import SwiftUI

struct MiniPlayerView: View {
    var viewModel: NarratorViewModel

    private var progress: Double {
        guard viewModel.audioPlayer.duration > 0 else { return 0 }
        return viewModel.audioPlayer.currentPosition / viewModel.audioPlayer.duration
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thin progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.orange.opacity(0.15))

                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.1), value: progress)
                }
            }
            .frame(height: 3)

            HStack(spacing: 14) {
                // Waveform icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 42, height: 42)

                    if viewModel.isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.orange)
                    } else {
                        Image(systemName: "waveform")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.orange)
                            .symbolEffect(.variableColor.iterative.reversing, isActive: viewModel.audioPlayer.isPlaying)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentItem?.title ?? "")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if viewModel.isGenerating {
                        Text("Generating...")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text(viewModel.currentVoice.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Controls
                HStack(spacing: 16) {
                    Button {
                        viewModel.togglePlayPause()
                    } label: {
                        Image(systemName: viewModel.audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(viewModel.isGenerating)

                    Button {
                        viewModel.skipForward()
                    } label: {
                        Image(systemName: "goforward.15")
                            .font(.callout)
                            .frame(width: 28, height: 28)
                    }
                    .disabled(viewModel.isGenerating)
                }
                .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
}
