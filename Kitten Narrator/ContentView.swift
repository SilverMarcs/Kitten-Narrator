import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(NarratorViewModel.self) private var viewModel
    @Namespace private var playerNS

    private let artworkTransitionID = "now-playing-artwork"

    var body: some View {
        @Bindable var viewModel = viewModel

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

            case .error:
                errorView
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: viewModel.appState)
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
        LibraryView()
            .safeAreaBar(edge: .bottom) {
                if viewModel.currentItem != nil {
                    MiniPlayerView(
                        namespace: playerNS,
                        artworkID: artworkTransitionID
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

                Text("Waking up Narrator...")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Error

    private var errorView: some View {
        Text("Unknown Error")
    }
}

#Preview {
    ContentView()
        .environment(NarratorViewModel())
        .modelContainer(for: NarratorItem.self, inMemory: true)
}
