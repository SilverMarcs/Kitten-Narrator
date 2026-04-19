import SwiftUI
import SwiftData

struct LibraryView: View {
    var namespace: Namespace.ID

    @Environment(NarratorViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NarratorItem.sortOrder, order: .reverse) private var items: [NarratorItem]

    @Environment(\.accent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var filter: LibraryFilter = .all
    @State private var showSettings = false

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

    private var nowPlayingItem: NarratorItem? {
        guard let current = viewModel.currentItem else { return nil }
        return filteredItems.first { $0.id == current.id }
    }

    private var libraryItems: [NarratorItem] {
        guard let current = viewModel.currentItem else { return filteredItems }
        return filteredItems.filter { $0.id != current.id }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    LibraryEmptyState()
                } else if filteredItems.isEmpty {
                    noResultsState
                } else {
                    itemList
                }
            }
            .background(libraryBackdrop.ignoresSafeArea())
            .navigationTitle("Library")
            .toolbarTitleDisplayMode(.inlineLarge)
            .searchable(text: $searchText, prompt: "Search narrations")
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                    .matchedTransitionSource(id: "settings", in: namespace)
                }

                DefaultToolbarItem(kind: .search, placement: .bottomBar)

                ToolbarSpacer(.fixed, placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        viewModel.showAddContent = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .matchedTransitionSource(id: "addContent", in: namespace)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .navigationTransition(.zoom(sourceID: "settings", in: namespace))
            }
            .safeAreaBar(edge: .top, spacing: 0) {
                if !items.isEmpty {
                    LibraryFilterBar(
                        filter: $filter,
                        filteredCount: filteredItems.count,
                        showCount: filter != .all || !searchText.isEmpty
                    )
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

    // MARK: - No results

    private var noResultsState: some View {
        ContentUnavailableView {
            Label("No matches", systemImage: "text.magnifyingglass")
                .foregroundStyle(accent)
        } description: {
            Text(searchText.isEmpty
                 ? "Nothing here fits this filter yet."
                 : "Nothing matches \"\(searchText)\".")
        }
    }

    // MARK: - List

    private var itemList: some View {
        List {
            if let nowPlayingItem {
                Section("Now Playing") {
                    ItemRowView(item: nowPlayingItem, namespace: namespace)
                }
                .listRowBackground(sectionBackground)
            }

            Section("Playlist") {
                ForEach(libraryItems) { item in
                    ItemRowView(item: item, namespace: namespace)
                }
                .onMove(perform: moveItems)
            }
            .listRowBackground(sectionBackground)
        }
        .scrollContentBackground(.hidden)
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = libraryItems
        reordered.move(fromOffsets: source, toOffset: destination)
        let count = reordered.count
        for (index, item) in reordered.enumerated() {
            item.sortOrder = count - index
        }
    }

    private var sectionBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.04)
    }
}
