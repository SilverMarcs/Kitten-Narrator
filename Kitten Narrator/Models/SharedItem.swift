import Foundation

/// Lightweight item passed from the Share Extension to the main app via App Groups.
struct SharedItem: Codable {
    let id: UUID
    let title: String
    let content: String
    let sourceType: String
    let sourceURL: String?
    let createdAt: Date

    init(title: String, content: String, sourceType: String = "text", sourceURL: String? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.createdAt = Date()
    }
}

enum SharedItemStore {
    static let appGroupID = "group.com.SilverMarcs.KittenNarrator"
    private static let fileName = "shared_items.json"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static var fileURL: URL? {
        containerURL?.appendingPathComponent(fileName)
    }

    /// Append a new shared item (called from the Share Extension).
    static func save(_ item: SharedItem) {
        var items = load()
        items.append(item)
        guard let url = fileURL,
              let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Read all pending shared items (called from the main app).
    static func load() -> [SharedItem] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([SharedItem].self, from: data)) ?? []
    }

    /// Clear all pending shared items after import (called from the main app).
    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
