import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(NarratorViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NarratorItem.createdAt, order: .reverse) private var items: [NarratorItem]

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
                SettingsView()
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

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Label("Settings", systemImage: "slider.horizontal.3")
        }
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
            ForEach(filteredItems) { item in
                Button {
                    Task { await viewModel.playItem(item) }
                } label: {
                    ItemRowView(item: item)
                }
                .buttonStyle(.plain)
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
            .listRowBackground(sectionBackground)
        }
        .scrollContentBackground(.hidden)
    }

    private var sectionBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.black.opacity(0.04)
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
