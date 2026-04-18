import SwiftUI

struct LibraryEmptyState: View {
    @Environment(NarratorViewModel.self) private var viewModel
    @Environment(\.accent) private var accent

    var body: some View {
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
}
