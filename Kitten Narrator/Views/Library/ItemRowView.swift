import SwiftUI

struct ItemRowView: View {
    let item: NarratorItem
    var namespace: Namespace.ID
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

    private var artworkImageURL: URL? {
        guard let str = item.artworkURL else { return nil }
        return URL(string: str)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                // Text(item.content)
                    // .font(.caption)
                    // .lineLimit(1)
                    // .foregroundStyle(.secondary)

                bottomRow
            }
        }
        .contentShape(.rect)
    }

    // MARK: - Avatar

    private var avatar: some View {
        ZStack {
            if let artworkImageURL {
                AsyncImage(url: artworkImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }

            if isGenerating || isPlayingNow || isCurrentItem {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isCurrentItem && artworkImageURL != nil
                        ? AnyShapeStyle(.black.opacity(0.4))
                        : AnyShapeStyle(Color.clear)
                    )

                Group {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
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
                    }
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .matchedTransitionSource(id: item.id.uuidString, in: namespace)
    }

    private var fallbackAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isCurrentItem
                    ? AnyShapeStyle(accent.brandGradient)
                    : AnyShapeStyle(accent.opacity(0.18))
                )

            if !isGenerating && !isPlayingNow && !isCurrentItem {
                Image(systemName: item.sourceIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
            }
        }
    }

    // MARK: - Bottom row

    private var bottomRow: some View {
        HStack(spacing: 0) {
            durationPill

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if item.hasGeneratedAudio {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(item.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var durationPill: some View {
        HStack(spacing: 5) {
            Image(systemName: isPlayingNow ? "pause.fill" : "play.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)

            Group {
                if isGenerating {
                    Text("Generating...")
                        .foregroundStyle(accent)
                } else if item.hasGeneratedAudio {
                    Text(formatDuration(item.audioDuration))
                } else {
                    Text(item.estimatedListenTime)
                }
            }
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.fill.tertiary, in: Capsule())
    }
}
