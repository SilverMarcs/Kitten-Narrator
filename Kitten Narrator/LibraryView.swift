import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NarratorItem.createdAt, order: .reverse) private var items: [NarratorItem]
    var viewModel: NarratorViewModel

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .navigationTitle("Narrator")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showAddContent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to Listen To", systemImage: "headphones")
                .foregroundStyle(.orange)
        } description: {
            Text("Add some text or a URL and Narrator will\nturn it into audio you can listen to anywhere.")
        } actions: {
            Button {
                viewModel.showAddContent = true
            } label: {
                Text("Add Content")
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }

    // MARK: - Item List

    private var itemList: some View {
        List {
            ForEach(items) { item in
                Button {
                    Task { await viewModel.playItem(item) }
                } label: {
                    ItemRowView(item: item, viewModel: viewModel)
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
                            try? FileManager.default.removeItem(at: item.audioCacheURL)
                            item.playbackPosition = 0
                            item.audioDuration = 0
                            item.isCompleted = false
                        } label: {
                            Label("Clear Audio", systemImage: "arrow.clockwise")
                        }
                        .tint(.blue)
                    }
                }
                .contextMenu {
                    Button {
                        Task { await viewModel.playItem(item) }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }

                    if item.hasGeneratedAudio {
                        Button {
                            try? FileManager.default.removeItem(at: item.audioCacheURL)
                            item.playbackPosition = 0
                            item.audioDuration = 0
                            item.isCompleted = false
                        } label: {
                            Label("Regenerate Audio", systemImage: "arrow.clockwise")
                        }
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
    }

    private func deleteItem(_ item: NarratorItem) {
        if viewModel.currentItem?.id == item.id {
            viewModel.stop()
        }
        try? FileManager.default.removeItem(at: item.audioCacheURL)
        withAnimation {
            modelContext.delete(item)
        }
    }
}
