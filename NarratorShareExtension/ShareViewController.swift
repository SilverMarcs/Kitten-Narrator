import UIKit
import PDFKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        Task {
            for extensionItem in extensionItems {
                guard let attachments = extensionItem.attachments else { continue }

                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        await handleURL(attachment)
                        return
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        await handleText(attachment)
                        return
                    } else if attachment.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                        await handlePDF(attachment)
                        return
                    }
                }
            }
            close()
        }
    }

    private func handleURL(_ attachment: NSItemProvider) async {
        do {
            let item = try await attachment.loadItem(forTypeIdentifier: UTType.url.identifier)
            if let url = item as? URL {
                let shared = SharedItem(
                    title: url.host ?? "Shared Link",
                    content: url.absoluteString,
                    sourceType: "shared_url",
                    sourceURL: url.absoluteString
                )
                SharedItemStore.save(shared)
            }
        } catch {}
        close()
    }

    private func handleText(_ attachment: NSItemProvider) async {
        do {
            let item = try await attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            if let text = item as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { close(); return }

                if (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")),
                   let url = URL(string: trimmed) {
                    let shared = SharedItem(
                        title: url.host ?? "Shared Link",
                        content: trimmed,
                        sourceType: "shared_url",
                        sourceURL: trimmed
                    )
                    SharedItemStore.save(shared)
                } else {
                    let shared = SharedItem(
                        title: String(trimmed.prefix(60)),
                        content: trimmed,
                        sourceType: "text"
                    )
                    SharedItemStore.save(shared)
                }
            }
        } catch {}
        close()
    }

    private func handlePDF(_ attachment: NSItemProvider) async {
        do {
            let item = try await attachment.loadItem(forTypeIdentifier: UTType.pdf.identifier)
            var pdfData: Data?

            if let url = item as? URL {
                pdfData = try? Data(contentsOf: url)
            } else if let data = item as? Data {
                pdfData = data
            }

            if let data = pdfData, let doc = PDFDocument(data: data) {
                var text = ""
                for i in 0..<doc.pageCount {
                    if let page = doc.page(at: i), let pageText = page.string {
                        text += pageText + "\n\n"
                    }
                }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { close(); return }
                let shared = SharedItem(
                    title: String(trimmed.prefix(60)),
                    content: trimmed,
                    sourceType: "pdf"
                )
                SharedItemStore.save(shared)
            }
        } catch {}
        close()
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
