import SwiftUI

struct TranscriptStageView: View {
    @Environment(NarratorViewModel.self) private var viewModel
    @Environment(\.accent) private var accent

    var artworkImageURL: URL?
    var artworkNS: Namespace.ID

    private var voice: VoiceOption {
        viewModel.currentVoice
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                artworkThumbnail
                    .matchedGeometryEffect(id: "artwork-transition", in: artworkNS)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentItem?.title ?? "Untitled")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(voice.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                speedMenu
            }
            .padding(.horizontal, 24)

            transcriptScroll
                .clipped()
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }

    private var speedMenu: some View {
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

    private var artworkThumbnail: some View {
        Group {
            if let artworkImageURL {
                AsyncImage(url: artworkImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        fallbackThumbnail
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                fallbackThumbnail
            }
        }
    }

    private var fallbackThumbnail: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(voice.gradient)
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: "waveform")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
            )
    }

    private var transcriptScroll: some View {
        let words = (viewModel.currentItem?.content ?? "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let activeIndex = viewModel.currentWordIndex

        return ScrollViewReader { proxy in
            ScrollView {
                FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
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
            .contentMargins(0, for: .scrollContent)
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
}
