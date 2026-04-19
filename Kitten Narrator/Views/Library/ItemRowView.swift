import SwiftUI
import SwiftData

struct ItemRowView: View {
    let item: NarratorItem
    var namespace: Namespace.ID
    @Environment(NarratorViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
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
        Button {
            Task { await viewModel.playItem(item) }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                avatar

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text(item.content)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)

                    bottomRow
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteItem()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if item.hasGeneratedAudio {
                Button {
                    clearAudio()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                .tint(.blue)
            }

            Button {
                item.isCompleted.toggle()
                if item.isCompleted { item.playbackPosition = 0 }
            } label: {
                Label(item.isCompleted ? "Mark unread" : "Mark read",
                      systemImage: item.isCompleted ? "circle" : "checkmark.circle")
            }
            .tint(.green)
        }
        .contextMenu {
            Button {
                Task { await viewModel.playItem(item) }
            } label: {
                Label("Play Audio", systemImage: "play.fill")
            }

            if item.hasGeneratedAudio {
                Button {
                    clearAudio()
                } label: {
                    Label("Regenerate audio", systemImage: "arrow.clockwise")
                }
            }
            
            Divider()

            Button {
                item.isCompleted.toggle()
                if item.isCompleted { item.playbackPosition = 0 }
            } label: {
                Label(item.isCompleted ? "Mark as unread" : "Mark as read",
                      systemImage: item.isCompleted ? "circle" : "checkmark.circle")
            }

            Divider()

            Button {
                deleteItem()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
        HStack(spacing: 6) {
            Image(systemName: isPlayingNow ? "pause.fill" : "play.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)

            if item.hasGeneratedAudio && item.progressPercentage > 0.005 && !item.isCompleted {
                Capsule()
                    .fill(accent.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(accent)
                            .frame(width: 40 * item.progressPercentage)
                    }
            }

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
            .foregroundStyle(accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.fill.tertiary, in: Capsule())
    }

    // MARK: - Actions

    private func deleteItem() {
        if isCurrentItem {
            viewModel.stop()
        }
        try? FileManager.default.removeItem(at: item.audioCacheURL)
        try? FileManager.default.removeItem(at: item.wordTimingsCacheURL)
        withAnimation {
            modelContext.delete(item)
        }
    }

    private func clearAudio() {
        try? FileManager.default.removeItem(at: item.audioCacheURL)
        try? FileManager.default.removeItem(at: item.wordTimingsCacheURL)
        item.playbackPosition = 0
        item.audioDuration = 0
        item.isCompleted = false
    }
}
