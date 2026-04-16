import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var viewModel = NarratorViewModel()

    var body: some View {
        Group {
            switch viewModel.appState {
            case .loading:
                loadingView

            case .downloading(let progress):
                ModelDownloadView(progress: progress)

            case .ready:
                mainContent

            case .error(let message):
                errorView(message)
            }
        }
        .tint(.orange)
        .task {
            await viewModel.initialize()
        }
        .sheet(isPresented: $viewModel.showAddContent) {
            AddContentView()
        }
        .sheet(isPresented: $viewModel.showNowPlaying) {
            NavigationStack {
                NowPlayingView(viewModel: viewModel)
            }
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(28)
        }
        .onChange(of: viewModel.audioPlayer.isPlaying) {
            viewModel.saveCurrentPosition()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            LibraryView(viewModel: viewModel)
                .safeAreaPadding(.bottom, viewModel.currentItem != nil ? 60 : 0)

            if viewModel.currentItem != nil {
                MiniPlayerView(viewModel: viewModel)
                    .onTapGesture {
                        viewModel.showNowPlaying = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.3), value: viewModel.currentItem?.id)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Initializing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Setup Failed", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } description: {
            Text(message)
        } actions: {
            Button {
                Task { await viewModel.initialize() }
            } label: {
                Text("Retry")
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: NarratorItem.self, inMemory: true)
}
