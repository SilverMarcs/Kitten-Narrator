import SwiftUI
import SwiftData

struct AddContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var textTitle = ""
    @State private var textContent = ""
    @State private var urlString = ""
    @State private var isLoadingURL = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Source", selection: $selectedTab) {
                    Label("Text", systemImage: "text.alignleft").tag(0)
                    Label("URL", systemImage: "link").tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .padding(.horizontal)

                if selectedTab == 0 {
                    textInputSection
                } else {
                    urlInputSection
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Add Content")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoadingURL {
                        ProgressView()
                    } else {
                        Button("Add") { addItem() }
                            .bold()
                            .disabled(!canAdd)
                    }
                }
            }
            .animation(.default, value: selectedTab)
        }
    }

    // MARK: - Text Input

    @ViewBuilder
    private var textInputSection: some View {
        Section("Title") {
            TextField("Give it a name", text: $textTitle)
        }

        Section("Content") {
            TextEditor(text: $textContent)
                .frame(minHeight: 180)

            if !textContent.isEmpty {
                HStack {
                    Spacer()
                    Text("\(textContent.split(separator: " ").count) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            Button {
                pasteFromClipboard()
            } label: {
                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
            }
        }
    }

    // MARK: - URL Input

    @ViewBuilder
    private var urlInputSection: some View {
        Section("URL") {
            TextField("https://example.com/article", text: $urlString)
                #if os(iOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                #endif
                .textContentType(.URL)
        }

        if isLoadingURL {
            Section {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Fetching article...")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private var canAdd: Bool {
        if selectedTab == 0 {
            return !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingURL
        }
    }

    private func addItem() {
        errorMessage = nil
        if selectedTab == 0 {
            addTextItem()
        } else {
            fetchURL()
        }
    }

    private func addTextItem() {
        let content = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = textTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty ? String(content.prefix(60)) : title

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
            errorMessage = "Invalid URL"
            return
        }

        isLoadingURL = true
        errorMessage = nil

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
                let extracted = TextExtractor.extractFromHTML(html)

                let content = extracted.content
                guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    errorMessage = "Could not extract text from this URL"
                    isLoadingURL = false
                    return
                }

                let title = extracted.title ?? url.host ?? "Web Article"
                let item = NarratorItem(
                    title: title,
                    content: content,
                    sourceType: "url",
                    sourceURL: urlText
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

    private func pasteFromClipboard() {
        #if os(iOS)
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        #elseif os(macOS)
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        #else
        return
        #endif

        #if !os(xrOS)
        textContent = text
        if textTitle.isEmpty {
            textTitle = String(text.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
    }
}
