import SwiftUI

struct NowPlayingView: View {
    @Environment(NarratorViewModel.self) private var viewModel
    var namespace: Namespace.ID
    var artworkID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    @State private var showLyrics = false
    @Namespace private var artworkNS

    private var voice: VoiceOption {
        viewModel.currentVoice
    }

    private var artworkImageURL: URL? {
        guard let str = viewModel.currentItem?.artworkURL else { return nil }
        return URL(string: str)
    }

    private let largeCornerRadius: CGFloat = 28
    private let smallCornerRadius: CGFloat = 10
    private let thumbnailSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            stageArea
                .frame(maxHeight: .infinity)

            PlayerDockView(showLyrics: $showLyrics)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .fixedSize(horizontal: false, vertical: true)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            dragHandle
                .padding(.top, 2)
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
            .frame(width: 50, height: 5)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    // MARK: - Stage area

    private var stageArea: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - 56 // 28pt padding each side

            VStack(spacing: 16) {
                if !showLyrics {
                    Spacer(minLength: 0)
                }

                artworkRow

                if showLyrics {
                    transcriptScroll
                        .clipped()
                        .padding(.bottom, 16)
                        .transition(.opacity)
                } else {
                    titleSection
                        .transition(.opacity)

                    Spacer(minLength: 0)
                }
            }
            .frame(width: contentWidth)
            .frame(maxWidth: .infinity)
            .animation(.smooth(duration: 0.45), value: showLyrics)
        }
    }

    // MARK: - Artwork row

    private var artworkRow: some View {
        let isSmall = showLyrics
        let corners = isSmall ? smallCornerRadius : largeCornerRadius

        return HStack(spacing: isSmall ? 12 : 0) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: isSmall ? thumbnailSize : .infinity)
                .overlay {
                    artworkImage
                        .aspectRatio(contentMode: .fill)
                }
                .clipShape(RoundedRectangle(cornerRadius: corners, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corners, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(isSmall ? 0 : 0.55), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isSmall ? 0 : 1
                        )
                )
                .compositingGroup()
                .shadow(
                    color: voice.color.opacity(isSmall ? 0 : 0.45),
                    radius: isSmall ? 0 : 40,
                    y: isSmall ? 0 : 20
                )

            if isSmall {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.currentItem?.title ?? "Untitled")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(voice.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    speedMenu
                }
                .matchedGeometryEffect(id: "titleRow", in: artworkNS, properties: .position)
            }
        }
    }

    // MARK: - Artwork image

    @ViewBuilder
    private var artworkImage: some View {
        if let artworkImageURL {
            AsyncImage(url: artworkImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    fallbackArtwork
                }
            }
        } else {
            fallbackArtwork
        }
    }

    private var fallbackArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: showLyrics ? smallCornerRadius : largeCornerRadius, style: .continuous)
                .fill(voice.gradient)

            Image(systemName: "waveform")
                .font(.system(size: showLyrics ? 28 : 92, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .symbolEffect(.variableColor.iterative.reversing,
                              options: .repeat(.continuous),
                              isActive: viewModel.audioPlayer.isPlaying)
        }
    }

    // MARK: - Title section

    private var titleSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentItem?.title ?? "Untitled")
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(voice.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(accent)
            }

            Spacer(minLength: 0)

            speedMenu
        }
        .matchedGeometryEffect(id: "titleRow", in: artworkNS, properties: .position)
    }

    // MARK: - Speed menu

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

    // MARK: - Transcript scroll

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
                .padding(8)
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
