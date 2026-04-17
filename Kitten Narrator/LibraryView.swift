import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NarratorItem.createdAt, order: .reverse) private var items: [NarratorItem]
    var viewModel: NarratorViewModel

    @Environment(\.accent) private var accent

    @State private var searchText = ""
    @State private var filter: LibraryFilter = .all
    @State private var showSettings = false

    enum LibraryFilter: String, CaseIterable, Identifiable {
        case all, unfinished, completed
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: "All"
            case .unfinished: "In progress"
            case .completed: "Finished"
            }
        }
        var icon: String {
            switch self {
            case .all: "square.stack"
            case .unfinished: "hourglass"
            case .completed: "checkmark.circle"
            }
        }
    }

    // MARK: - Derived

    private var filteredItems: [NarratorItem] {
        items.filter { item in
            let matchesFilter: Bool = {
                switch filter {
                case .all: return true
                case .unfinished: return !item.isCompleted
                case .completed: return item.isCompleted
                }
            }()

            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch: Bool = q.isEmpty ||
                item.title.lowercased().contains(q) ||
                item.content.lowercased().contains(q)

            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else if filteredItems.isEmpty {
                    noResultsState
                } else {
                    itemList
                }
            }
            .background(libraryBackdrop.ignoresSafeArea())
            .navigationTitle("Library")
            #if os(iOS)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search narrations")
            #else
            .searchable(text: $searchText, prompt: "Search narrations")
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    settingsButton
                }
                #else
                ToolbarItem(placement: .navigation) {
                    settingsButton
                }
                #endif

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showAddContent = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !items.isEmpty {
                    filterBar
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    // MARK: - Backdrop

    private var libraryBackdrop: some View {
        ZStack {
            Color.appBackground
            LinearGradient(
                colors: [
                    accent.opacity(0.10),
                    accent.opacity(0.03),
                    .clear,
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .animation(.smooth(duration: 0.6), value: accent)
    }

    // MARK: - Toolbar helpers

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Label("Settings", systemImage: "slider.horizontal.3")
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases) { f in
                    let selected = filter == f
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { filter = f }
                        #if os(iOS)
                        UISelectionFeedbackGenerator().selectionChanged()
                        #endif
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: f.icon)
                                .font(.caption.weight(.bold))
                            Text(f.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(selected ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        selected
                        ? .regular.tint(accent.opacity(0.85)).interactive()
                        : .regular.interactive(),
                        in: .capsule
                    )
                }

                Spacer(minLength: 0)

                if filter != .all || !searchText.isEmpty {
                    Text("\(filteredItems.count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .fill(accent.softSurface)
                        .frame(width: 160, height: 160)
                    Image(systemName: "headphones")
                        .font(.system(size: 58, weight: .medium))
                        .foregroundStyle(accent.brandGradient)
                }

                VStack(spacing: 10) {
                    Text("Your library is quiet")
                        .font(.title2.bold())
                    Text("Paste an article, drop in a URL,\nor type your own words.\nNarrator handles the rest.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                Button {
                    viewModel.showAddContent = true
                } label: {
                    Label("Add something to listen to", systemImage: "plus.circle.fill")
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
        }
    }

    private var noResultsState: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "text.magnifyingglass")
                .foregroundStyle(accent)
        } description: {
            Text(searchText.isEmpty
                 ? "Nothing here fits this filter yet."
                 : "Nothing matches “\(searchText)”.")
        }
    }

    // MARK: - List

    private var itemList: some View {
        List {
            ForEach(filteredItems) { item in
                Button {
                    Task { await viewModel.playItem(item) }
                } label: {
                    ItemRowView(item: item, viewModel: viewModel)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteItem(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if item.hasGeneratedAudio {
                        Button {
                            clearAudio(item)
                        } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                        }
                        .tint(.blue)
                    }

                    Button {
                        item.isCompleted.toggle()
                        if item.isCompleted { item.playbackPosition = 0 }
                    } label: {
                        Label(item.isCompleted ? "Mark unread" : "Mark read",
                              systemImage: item.isCompleted ? "circle" : "checkmark.circle")
                    }
                    .tint(.green)
                }
                .contextMenu {
                    Button {
                        Task { await viewModel.playItem(item) }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }

                    if item.hasGeneratedAudio {
                        Button {
                            clearAudio(item)
                        } label: {
                            Label("Regenerate audio", systemImage: "arrow.clockwise")
                        }
                    }

                    Button {
                        item.isCompleted.toggle()
                        if item.isCompleted { item.playbackPosition = 0 }
                    } label: {
                        Label(item.isCompleted ? "Mark as unread" : "Mark as read",
                              systemImage: item.isCompleted ? "circle" : "checkmark.circle")
                    }

                    Divider()

                    Button(role: .destructive) {
                        deleteItem(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func deleteItem(_ item: NarratorItem) {
        if viewModel.currentItem?.id == item.id {
            viewModel.stop()
        }
        try? FileManager.default.removeItem(at: item.audioCacheURL)
        withAnimation {
            modelContext.delete(item)
        }
    }

    private func clearAudio(_ item: NarratorItem) {
        try? FileManager.default.removeItem(at: item.audioCacheURL)
        item.playbackPosition = 0
        item.audioDuration = 0
        item.isCompleted = false
    }
}
