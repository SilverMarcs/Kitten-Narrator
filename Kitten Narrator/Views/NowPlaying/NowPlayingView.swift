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

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Group {
                    if showLyrics {
                        TranscriptStageView(artworkImageURL: artworkImageURL, artworkNS: artworkNS)
                            .transition(.opacity)
                    } else {
                        artworkStage
                            .transition(.opacity)
                    }
                }
                .frame(height: geo.size.height * 0.7)

                PlayerDockView(showLyrics: $showLyrics)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .frame(height: geo.size.height * 0.3, alignment: .top)
            }
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

    // MARK: - Artwork stage

    private var artworkStage: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            artwork
                .matchedGeometryEffect(id: "artwork-transition", in: artworkNS)
                .frame(maxWidth: 320)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)

            titleSection
                .padding(.horizontal, 28)

            Spacer(minLength: 0)
        }
    }

    private let artworkCornerRadius: CGFloat = 28

    private var artwork: some View {
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
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }

            RoundedRectangle(cornerRadius: artworkCornerRadius, style: .continuous)
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
                    Text("Generating audio...")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: artworkCornerRadius, style: .continuous))
        .shadow(color: voice.color.opacity(0.45), radius: 40, y: 20)
    }

    private var fallbackArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: artworkCornerRadius, style: .continuous)
                .fill(voice.gradient)

            Image(systemName: "waveform")
                .font(.system(size: 92, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .symbolEffect(.variableColor.iterative.reversing,
                              options: .repeat(.continuous),
                              isActive: viewModel.audioPlayer.isPlaying)
        }
    }

    private var titleSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentItem?.title ?? "Untitled")
                    .font(.title3.bold())
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(voice.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(accent)
            }

            Spacer(minLength: 0)

            speedMenu
        }
        .matchedGeometryEffect(id: "titleRow-transition", in: artworkNS, properties: .position)
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
}
