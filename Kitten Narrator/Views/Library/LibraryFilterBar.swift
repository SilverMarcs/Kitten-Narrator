import SwiftUI

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

struct LibraryFilterBar: View {
    @Binding var filter: LibraryFilter
    var filteredCount: Int
    var showCount: Bool

    @Environment(\.accent) private var accent

    var body: some View {
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

                if showCount {
                    Text("\(filteredCount)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                        .contentTransition(.numericText())
//                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}
