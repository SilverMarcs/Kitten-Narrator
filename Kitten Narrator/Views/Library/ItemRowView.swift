import SwiftUI

struct ItemRowView: View {
    let item: NarratorItem
    @Environment(NarratorViewModel.self) private var viewModel
    @Environment(\.accent) private var accent

    private var isCurrentItem: Bool {
        viewModel.currentItem?.id == item.id
    }

    private var isGenerating: Bool {
        viewModel.generatingItemID == item.id
    }

    private var isPlayingNow: Bool {
        isCurrentItem && viewModel.audioPlayer.isPlaying
    }

    var body: some View {
        HStack(spacing: 14) {
            avatar
            content
            Spacer(minLength: 0)
            trailing
        }
        .contentShape(.rect)
        .animation(.snappy(duration: 0.25), value: isCurrentItem)
    }

    // MARK: - Avatar

    private var avatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isCurrentItem
                    ? AnyShapeStyle(accent.brandGradient)
                    : AnyShapeStyle(accent.opacity(0.18))
                )
                .frame(width: 56, height: 56)

            Group {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(isCurrentItem ? .white : accent)
                } else if isPlayingNow {
                    Image(systemName: "waveform")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative.reversing,
                                      options: .repeat(.continuous))
                } else if isCurrentItem {
                    Image(systemName: "pause.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: item.sourceIcon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            Divider()

            HStack(spacing: 8) {
                Group {
                    if isGenerating {
                        Label("Generating", systemImage: "sparkles")
                            .foregroundStyle(accent)
                    } else if item.hasGeneratedAudio {
                        Label(formatDuration(item.audioDuration), systemImage: "clock")
                    } else {
                        Label(item.estimatedListenTime, systemImage: "clock")
                    }
                }
                .labelIconToTitleSpacing(5)

                if item.isCompleted {
                    Dot()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            if item.hasGeneratedAudio && item.progressPercentage > 0.005 && !item.isCompleted {
                progressBar
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            Capsule()
                .fill(.secondary.opacity(0.15))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(isCurrentItem ? AnyShapeStyle(accent.brandGradient)
                                            : AnyShapeStyle(Color.secondary.opacity(0.6)))
                        .frame(width: geo.size.width * item.progressPercentage)
                }
        }
        .frame(height: 3)
        .clipShape(Capsule())
        .padding(.top, 2)
    }

    // MARK: - Trailing

    @ViewBuilder
    private var trailing: some View {
        if !isCurrentItem {
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: item.hasGeneratedAudio ? "play.circle" : "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(accent.opacity(0.85))
            }
        }
    }
}

private struct Dot: View {
    var body: some View {
        Circle()
            .fill(.secondary.opacity(0.4))
            .frame(width: 3, height: 3)
    }
}
