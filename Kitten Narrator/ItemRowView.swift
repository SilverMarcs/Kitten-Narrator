import SwiftUI

struct ItemRowView: View {
    let item: NarratorItem
    let viewModel: NarratorViewModel

    private var isCurrentItem: Bool {
        viewModel.currentItem?.id == item.id
    }

    private var isGenerating: Bool {
        viewModel.generatingItemID == item.id
    }

    var body: some View {
        HStack(spacing: 14) {
            iconView
            contentView
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Icon

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCurrentItem ? Color.orange : Color.orange.opacity(0.1))
                .frame(width: 50, height: 50)

            Group {
                if isGenerating {
                    ProgressView()
                        .tint(isCurrentItem ? .white : .orange)
                } else if isCurrentItem && viewModel.audioPlayer.isPlaying {
                    Image(systemName: "waveform")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative.reversing)
                } else if isCurrentItem {
                    Image(systemName: "pause.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: item.sourceIcon)
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.title)
                .font(.body.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            HStack(spacing: 6) {
                if item.hasGeneratedAudio {
                    Label(formatDuration(item.audioDuration), systemImage: "clock")
                } else {
                    Label("\(item.wordCount) words", systemImage: "text.word.spacing")
                }

                Circle()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 3, height: 3)

                Text(item.createdAt, style: .relative)
                    .lineLimit(1)

                if item.isCompleted {
                    Circle()
                        .fill(.secondary.opacity(0.5))
                        .frame(width: 3, height: 3)

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Progress indicator
            if item.hasGeneratedAudio && item.progressPercentage > 0.01 && !item.isCompleted {
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.orange)
                                .frame(width: geo.size.width * item.progressPercentage)
                        }
                }
                .frame(height: 3)
                .clipShape(Capsule())
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins == 0 { return "\(secs)s" }
        return String(format: "%d:%02d", mins, secs)
    }
}
