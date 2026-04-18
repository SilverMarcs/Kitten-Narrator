import SwiftUI

struct NowPlayingView: View {
    @Environment(NarratorViewModel.self) private var viewModel
    var namespace: Namespace.ID
    var artworkID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    @State private var showLyrics = true
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
}
