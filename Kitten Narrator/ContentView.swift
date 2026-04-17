import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var viewModel = NarratorViewModel()
    @Namespace private var playerNS

    private let artworkTransitionID = "now-playing-artwork"

    var body: some View {
        Group {
            switch viewModel.appState {
            case .loading:
                loadingView
                    .transition(.opacity)

            case .downloading(let progress):
                ModelDownloadView(progress: progress)
                    .transition(.opacity)

            case .ready:
                mainContent
                    .transition(.opacity)

            case .error(let message):
                errorView(message)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: viewModel.appState)
        // Whole-app theming driven by the selected voice
        .tint(viewModel.currentVoice.color)
        .environment(\.accent, viewModel.currentVoice.color)
        .task {
            await viewModel.initialize()
        }
        .sheet(isPresented: $viewModel.showAddContent) {
            AddContentView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $viewModel.showNowPlaying) {
            nowPlayingSheet
        }
        .onChange(of: viewModel.audioPlayer.isPlaying) {
            viewModel.saveCurrentPosition()
        }
    }

    @ViewBuilder
    private var nowPlayingSheet: some View {
        let root = NavigationStack {
            NowPlayingView(
                viewModel: viewModel,
                namespace: playerNS,
                artworkID: artworkTransitionID
            )
        }
        .tint(viewModel.currentVoice.color)
        .environment(\.accent, viewModel.currentVoice.color)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.appBackground)

        #if os(iOS)
        root.navigationTransition(.zoom(sourceID: artworkTransitionID, in: playerNS))
        #else
        root.frame(minWidth: 520, minHeight: 720)
        #endif
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            LibraryView(viewModel: viewModel)
                .safeAreaPadding(.bottom, viewModel.currentItem != nil ? 84 : 0)

            if viewModel.currentItem != nil {
                MiniPlayerView(
                    viewModel: viewModel,
                    namespace: playerNS,
                    artworkID: artworkTransitionID,
                    onTap: { viewModel.showNowPlaying = true }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.35), value: viewModel.currentItem?.id)
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Brand.primary.opacity(0.10))
                        .frame(width: 120, height: 120)
                    Image(systemName: "waveform")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Brand.gradient)
                        .symbolEffect(.variableColor.iterative.reversing,
                                      options: .repeat(.continuous))
                }

                Text("Waking up Narrator…")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange.gradient)

                VStack(spacing: 8) {
                    Text("Setup hit a snag")
                        .font(.title2.bold())
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Button {
                    Task { await viewModel.initialize() }
                } label: {
                    Label("Try again", systemImage: "arrow.clockwise")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(Brand.primary)
                .controlSize(.large)
            }
            .padding(24)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: NarratorItem.self, inMemory: true)
}
