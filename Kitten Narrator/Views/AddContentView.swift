import SwiftUI
import SwiftData
import Reeeed
import PDFKit
#if os(iOS)
import UniformTypeIdentifiers
#endif

struct AddContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent
    @Environment(\.colorScheme) private var colorScheme

    enum Source: String, CaseIterable, Identifiable {
        case text, url, pdf
        var id: String { rawValue }
        var title: String {
            switch self {
            case .text: "Text"
            case .url: "Web Link"
            case .pdf: "PDF"
            }
        }
        var icon: String {
            switch self {
            case .text: "text.alignleft"
            case .url: "link"
            case .pdf: "doc.richtext"
            }
        }
    }

    @State private var source: Source = .text
    @State private var textTitle = ""
    @State private var textContent = ""
    @State private var urlString = ""
    @State private var isLoadingURL = false
    @State private var errorMessage: String?
    #if os(iOS)
    @State private var showDocumentPicker = false
    @State private var pdfTitle = ""
    @State private var pdfContent = ""
    @State private var pdfPageCount = 0
    #endif

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
                } else if source == .url {
                    urlSection
                } else if source == .pdf {
                    #if os(iOS)
                    pdfSection
                    #endif
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
                Text(source == .text ? "Paste or type some text" : source == .url ? "Drop in a web link" : "Import a PDF document")
                    .font(.headline)
                Text(source == .text
                     ? "Narrator will turn it magically into audio to listen offline."
                     : source == .url
                     ? "We'll extract the readable article for you from your desired article"
                     : "We'll extract all readable text from your PDF")
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
        switch source {
        case .text:
            return !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .url:
            return !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingURL
        case .pdf:
            #if os(iOS)
            return !pdfContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            #else
            return false
            #endif
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
        switch source {
        case .text: addTextItem()
        case .url: fetchURL()
        case .pdf:
            #if os(iOS)
            addPDFItem()
            #endif
        }
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

    #if os(iOS)
    private func addPDFItem() {
        let content = pdfContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = pdfTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = title.isEmpty
            ? String(content.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
            : title

        let item = NarratorItem(title: finalTitle, content: content, sourceType: "pdf")
        modelContext.insert(item)
        dismiss()
    }
    #endif

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

    // MARK: - PDF

    #if os(iOS)
    @ViewBuilder
    private var pdfSection: some View {
        if pdfContent.isEmpty {
            Section {
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Choose PDF", systemImage: "doc.richtext")
                        .frame(maxWidth: .infinity)
                        // .padding(.vertical, 8)
                }
                .buttonStyle(.borderless)
            }
            .listRowBackground(sectionBackground)
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url in
                    loadPDF(from: url)
                }
            }
        } else {
            Section("Title") {
                TextField("Optional title", text: $pdfTitle)
            }
            .listRowBackground(sectionBackground)

            Section {
                Text(String(pdfContent.prefix(500)) + (pdfContent.count > 500 ? "…" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(8)
            } header: {
                Text("Preview")
            } footer: {
                HStack {
                    Text("\(pdfContent.split(separator: " ").count) words")
                    Spacer()
                    Text("\(pdfPageCount) page\(pdfPageCount == 1 ? "" : "s")")
                }
            }
            .listRowBackground(sectionBackground)

            Section {
                Button {
                    pdfContent = ""
                    pdfTitle = ""
                    pdfPageCount = 0
                    showDocumentPicker = true
                } label: {
                    Label("Choose Different PDF", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderless)
            }
            .listRowBackground(sectionBackground)
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url in
                    loadPDF(from: url)
                }
            }
        }
    }

    private func loadPDF(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Couldn't access the selected file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: url) else {
            errorMessage = "Couldn't read this PDF."
            return
        }

        var text = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                text += pageText + "\n\n"
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "This PDF doesn't contain any readable text (it may be scanned images)."
            return
        }

        pdfContent = trimmed
        pdfPageCount = document.pageCount
        pdfTitle = url.deletingPathExtension().lastPathComponent
        errorMessage = nil
    }
    #endif
}

// MARK: - Document Picker

#if os(iOS)
struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
#endif
