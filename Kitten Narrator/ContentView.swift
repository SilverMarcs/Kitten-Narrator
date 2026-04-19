import SwiftUI
import SwiftData
import Reeeed

struct ContentView: View {
    @Environment(NarratorViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var playerNS

    #if os(iOS)
    @State private var clipboardContent: ClipboardContent?
    @State private var showClipboardBanner = false
    @State private var lastClipboardHash: Int?
    #endif

    private var artworkTransitionID: String {
        viewModel.currentItem?.id.uuidString ?? "now-playing-artwork"
    }

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
            #if os(iOS)
            if viewModel.appState == .ready {
                importSharedItems()
            }
            #endif
        }
        .sheet(isPresented: $viewModel.showAddContent) {
            AddContentView()
                .navigationTransition(.zoom(sourceID: "addContent", in: playerNS))
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
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: .sharedContentReceived)) { _ in
            if viewModel.appState == .ready {
                importSharedItems()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active && viewModel.appState == .ready {
                importSharedItems()
                checkClipboard()
            }
        }
        .overlay(alignment: .bottom) {
            if showClipboardBanner, let content = clipboardContent {
                clipboardBannerView(content)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 80)
                    .padding(.horizontal, 16)
            }
        }
        #endif
    }

    @ViewBuilder
    private var nowPlayingSheet: some View {
        let root = NavigationStack {
            NowPlayingView(namespace: playerNS, artworkID: artworkTransitionID)
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
        LibraryView(namespace: playerNS)
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(viewModel.currentVoice.color.opacity(0.10))
                        .frame(width: 120, height: 120)
                    Image(systemName: "waveform")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(viewModel.currentVoice.gradient)
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

    // MARK: - Share Extension Import

    #if os(iOS)
    private func importSharedItems() {
        let groupID = "group.com.SilverMarcs.KittenNarrator"
        guard let ud = UserDefaults(suiteName: groupID) else { return }
        guard let content = ud.string(forKey: "sharedContent"), !content.isEmpty else { return }

        let sourceType = ud.string(forKey: "sharedSourceType") ?? "text"

        if sourceType == "shared_url" {
            let host = URL(string: content)?.host ?? "Shared Link"
            let item = NarratorItem(title: host, content: "", sourceType: "url", sourceURL: content)
            modelContext.insert(item)
            Task {
                await fetchURLForItem(item, urlString: content)
                if !item.content.isEmpty {
                    await viewModel.playItem(item)
                }
            }
        } else {
            let title = String(content.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
            let item = NarratorItem(title: title, content: content, sourceType: sourceType)
            modelContext.insert(item)
            Task {
                await viewModel.playItem(item)
            }
        }

        // Clear after import
        ud.removeObject(forKey: "sharedContent")
        ud.removeObject(forKey: "sharedSourceType")
        ud.removeObject(forKey: "sharedContentDate")
        ud.synchronize()
    }
    #endif

    // MARK: - Clipboard Detection

    #if os(iOS)
    enum ClipboardContent {
        case text(String)
        case url(String)

        var preview: String {
            switch self {
            case .text(let t): String(t.prefix(80))
            case .url(let u): u
            }
        }

        var icon: String {
            switch self {
            case .text: "doc.on.clipboard"
            case .url: "link"
            }
        }

        var label: String {
            switch self {
            case .text: "Text on clipboard"
            case .url: "Link on clipboard"
            }
        }
    }

    private func checkClipboard() {
        let pasteboard = UIPasteboard.general

        guard pasteboard.hasStrings || pasteboard.hasURLs else { return }

        let content: ClipboardContent
        if let url = pasteboard.url, url.scheme == "http" || url.scheme == "https" {
            content = .url(url.absoluteString)
        } else if let string = pasteboard.string,
                  !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip very short clipboard text (likely just a copied word)
            guard trimmed.count >= 50 else { return }
            // Check if it looks like a URL
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"),
               URL(string: trimmed) != nil {
                content = .url(trimmed)
            } else {
                content = .text(trimmed)
            }
        } else {
            return
        }

        // Don't re-prompt for the same clipboard content
        let hash = content.preview.hashValue
        guard hash != lastClipboardHash else { return }
        lastClipboardHash = hash

        clipboardContent = content
        withAnimation(.spring(duration: 0.4)) {
            showClipboardBanner = true
        }
    }

    private func clipboardBannerView(_ content: ClipboardContent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: content.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(viewModel.currentVoice.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(content.label)
                    .font(.subheadline.weight(.semibold))
                Text(content.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button("Narrate") {
                addFromClipboard(content)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.currentVoice.color)
            .controlSize(.small)

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showClipboardBanner = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        }
    }

    private func addFromClipboard(_ content: ClipboardContent) {
        withAnimation(.spring(duration: 0.3)) {
            showClipboardBanner = false
        }

        switch content {
        case .text(let text):
            let title = String(text.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
            let item = NarratorItem(title: title, content: text, sourceType: "clipboard")
            modelContext.insert(item)

        case .url(let urlString):
            let item = NarratorItem(title: "Loading…", content: "", sourceType: "url", sourceURL: urlString)
            modelContext.insert(item)
            // Fetch URL content in background
            Task {
                await fetchURLForItem(item, urlString: urlString)
            }
        }
    }

    private func fetchURLForItem(_ item: NarratorItem, urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        do {
            let doc = try await Reeeed.fetchAndExtractContent(fromURL: url)
            let text = doc.extracted.extractPlainText
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            item.title = doc.title ?? url.host ?? "Web Article"
            item.content = text
            item.artworkURL = doc.metadata.heroImage?.absoluteString
        } catch {
            item.title = "Failed to load"
            item.content = "Could not extract text from \(urlString)"
        }
    }
    #endif
}

#Preview {
    ContentView()
        .environment(NarratorViewModel())
        .modelContainer(for: NarratorItem.self, inMemory: true)
}
