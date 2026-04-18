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
                .tint(viewModel.currentVoice.color)
                .environment(\.accent, viewModel.currentVoice.color)
        }
        .fullScreenCover(isPresented: $viewModel.showNowPlaying) {
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
        #if os(iOS)
        root.navigationTransition(.zoom(sourceID: artworkTransitionID, in: playerNS))
        #else
        root.frame(minWidth: 520, minHeight: 720)
        #endif
    }

    // MARK: - Main Content

    private var mainContent: some View {
        LibraryView(viewModel: viewModel)
            .safeAreaBar(edge: .bottom) {
                if viewModel.currentItem != nil {
                    MiniPlayerView(
                        viewModel: viewModel,
                        namespace: playerNS,
                        artworkID: artworkTransitionID,
                        onTap: { viewModel.showNowPlaying = true }
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                }
            }
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
        Text("Unknown Error")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: NarratorItem.self, inMemory: true)
}
