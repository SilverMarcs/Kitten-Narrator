import SwiftUI
import SwiftData

struct AddContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

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
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        Picker("Source", selection: $source) {
                            ForEach(Source.allCases) { s in
                                Text(s.title).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: source) {
                            errorMessage = nil
                        }

                        Group {
                            if source == .text {
                                textSection
                            } else {
                                urlSection
                            }
                        }
                        .transition(.opacity)

                        if let error = errorMessage {
                            errorBanner(error)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .animation(.snappy(duration: 0.25), value: source)
                .animation(.snappy(duration: 0.25), value: errorMessage)

                primaryAction
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
            }
            .background(bgTint.ignoresSafeArea())
            .navigationTitle("New Narration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
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

            VStack(alignment: .leading, spacing: 4) {
                Text(source == .text ? "Paste or type some text" : "Drop in a web link")
                    .font(.headline)
                Text(source == .text
                     ? "Narrator will turn it into audio you can listen to anywhere."
                     : "We'll extract the readable article for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Text

    @ViewBuilder
    private var textSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                labeledField("Title") {
                    TextField("Optional title", text: $textTitle)
                        .focused($focusedField, equals: .title)
                        .textFieldStyle(.plain)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .content }
                }
            }
        }

        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Content")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    if !textContent.isEmpty {
                        Text("\(textContent.split(separator: " ").count) words · \(estimatedTime) min")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $textContent)
                        .focused($focusedField, equals: .content)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)

                    if textContent.isEmpty {
                        Text("Paste or write what you'd like narrated…")
                            .foregroundStyle(.secondary.opacity(0.6))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
            }
        }

        pasteButton
    }

    private var pasteButton: some View {
        #if os(iOS) || os(macOS)
        PasteButton(payloadType: String.self) { strings in
            guard let text = strings.first, !text.isEmpty else { return }
            Task { @MainActor in
                textContent = text
                if textTitle.isEmpty {
                    textTitle = String(text.prefix(60))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                focusedField = .content
            }
        }
        .tint(accent)
        .buttonBorderShape(.capsule)
        .labelStyle(.titleAndIcon)
        #else
        EmptyView()
        #endif
    }

    // MARK: - URL

    @ViewBuilder
    private var urlSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                labeledField("URL") {
                    TextField("https://example.com/article", text: $urlString)
                        .focused($focusedField, equals: .url)
                        .textFieldStyle(.plain)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .submitLabel(.go)
                        .onSubmit { if canAdd { addItem() } }
                }
            }
        }

        if isLoadingURL {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small).tint(accent)
                Text("Fetching article…")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }

        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("How it works", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)

                Text("Narrator downloads the page, extracts the main article, and creates an offline audio version you can listen to anywhere.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
            }
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.red)

            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(.red.opacity(0.25)), in: .rect(cornerRadius: 14))
    }

    // MARK: - Primary action

    private var primaryAction: some View {
        Button {
            addItem()
        } label: {
            HStack(spacing: 8) {
                if isLoadingURL {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: source == .text ? "plus.circle.fill" : "arrow.down.circle.fill")
                        .font(.body.weight(.bold))
                }
                Text(source == .text ? "Add to Library" : "Fetch Article")
                    .font(.callout.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(accent)
        .controlSize(.extraLarge)
        .disabled(!canAdd)
        .opacity(canAdd ? 1 : 0.55)
        .animation(.snappy, value: canAdd)
    }

    // MARK: - Helpers

    private var canAdd: Bool {
        if source == .text {
            return !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoadingURL
        }
    }

    private var estimatedTime: String {
        let words = textContent.split(separator: " ").count
        let minutes = Double(words) / 150.0
        return minutes < 1 ? "<1" : String(Int(ceil(minutes)))
    }

    private var bgTint: some View {
        LinearGradient(
            colors: [accent.opacity(0.10), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
        content()
            .font(.body)
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
                let (data, _) = try await URLSession.shared.data(from: url)
                let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
                let extracted = TextExtractor.extractFromHTML(html)

                let content = extracted.content
                guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    errorMessage = "We couldn't find any readable text at this URL."
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
}

// MARK: - Card wrapper

private struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}
