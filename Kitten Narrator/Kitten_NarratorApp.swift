import SwiftUI
import SwiftData

@main
struct Kitten_NarratorApp: App {
    @State private var viewModel = NarratorViewModel()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            NarratorItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
