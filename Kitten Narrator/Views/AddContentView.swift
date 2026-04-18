import SwiftUI
import SwiftData
import Reeeed

struct AddContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    enum Source: String, CaseIterable, Identifiable {
        case text, url
        var id: String { rawValue }
        var title: String { self == .text ? "Text" : "Web Link" }
        var icon: String { self == .text ? "text.alignleft" : "link" }
    }

    @State private var source: Source = .text
    @State private var textTitle = ""
    @State private var textContent = ""
    @State private var urlString = ""
    @State private var isLoadingURL = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?
    enum Field { case title, content, url }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                }
                .listRowBackground(sectionBackground)

                Section {
                    Picker("Source", selection: $source) {
                        ForEach(Source.allCases) { s in
                            Text(s.title).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.extraLarge)
                    .onChange(of: source) {
                        errorMessage = nil
                    }
                }
                .listSectionMargins(.horizontal, 0)
                .listSectionSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listSectionSpacing(.compact)

                if source == .text {
                    textSection
                } else {
                    urlSection
                }

                if let error = errorMessage {
                    Section {
                        errorBanner(error)
                    }
                    .listRowBackground(sectionBackground)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .formStyle(.grouped)
            .contentMargins(.top, 15)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(bgTint.ignoresSafeArea())
            .navigationTitle("New Narration")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .tint(accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { addItem() }
                        .tint(accent)
                        .disabled(!canAdd)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.brandGradient)
                    .frame(width: 52, height: 52)
                    .shadow(color: accent.opacity(0.35), radius: 12, y: 5)

                Image(systemName: source.icon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(source == .text ? "Paste or type some text" : "Drop in a web link")
                    .font(.headline)
                Text(source == .text
                     ? "Narrator will turn it magically into audio to listen offline."
                     : "We'll extract the readable article for you from your desired article")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Text

    @ViewBuilder
    private var textSection: some View {
        Section("Title") {
            TextField("Optional title", text: $textTitle)
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .content }
        }
        .listRowBackground(sectionBackground)

        Section {
            TextEditor(text: $textContent)
                .focused($focusedField, equals: .content)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if textContent.isEmpty {
                        Text("Paste or write what you'd like narrated...")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
        } header: {
            Text("Content")
        } footer: {
            if !textContent.isEmpty {
                Text("\(textContent.split(separator: " ").count) words")
            }
        }
        .listRowBackground(sectionBackground)
    }

    // MARK: - URL

    @ViewBuilder
    private var urlSection: some View {
        Section {
            TextField("Paste URL here", text: $urlString)
                .focused($focusedField, equals: .url)
                #if os(iOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .textContentType(.URL)
                .submitLabel(.go)
                .onSubmit { if canAdd { addItem() } }
                .overlay(alignment: .trailing) {
                    if isLoadingURL {
                        ProgressView().controlSize(.small)
                    }
                }
        } header: {
            Text("URL")
        } footer: {
            Text("Narrator downloads the page, extracts the main article, and creates an offline audio version")
        }
        .listRowBackground(sectionBackground)
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.footnote.weight(.medium))
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    // MARK: - Helpers

    private var canAdd: Bool {
        if source == .text {
            return !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingURL
        }
    }

    private var bgTint: some View {
        LinearGradient(
            colors: [accent.opacity(0.10), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var sectionBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.04)
    }

    // MARK: - Actions

    private func addItem() {
        errorMessage = nil
        focusedField = nil
        if source == .text { addTextItem() } else { fetchURL() }
    }

    private func addTextItem() {
        let content = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = textTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty
            ? String(content.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
            : title

        let item = NarratorItem(title: finalTitle, content: content)
        modelContext.insert(item)
        dismiss()
    }

    private func fetchURL() {
        var urlText = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlText.hasPrefix("http://") && !urlText.hasPrefix("https://") {
            urlText = "https://\(urlText)"
        }

        guard let url = URL(string: urlText) else {
            errorMessage = "That doesn't look like a valid URL."
            return
        }

        isLoadingURL = true
        errorMessage = nil

        Task {
            do {
                let doc = try await Reeeed.fetchAndExtractContent(fromURL: url)
                let content = doc.extracted.extractPlainText
                guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    errorMessage = "We couldn't find any readable text at this URL."
                    isLoadingURL = false
                    return
                }

                let title = doc.title ?? url.host ?? "Web Article"
                let item = NarratorItem(
                    title: title,
                    content: content,
                    sourceType: "url",
                    sourceURL: urlText,
                    artworkURL: doc.metadata.heroImage?.absoluteString
                )
                modelContext.insert(item)
                isLoadingURL = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoadingURL = false
            }
        }
    }
}
