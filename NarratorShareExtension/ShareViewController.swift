import UIKit
import PDFKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private enum Const {
        static let groupID = "group.com.SilverMarcs.KittenNarrator"
        static let contentKey = "sharedContent"
        static let sourceTypeKey = "sharedSourceType"
        static let dateKey = "sharedContentDate"
        static let schemeURL = "kittennarrator://share"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        processIncomingItems()
    }

    private func processIncomingItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish()
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
            finish()
        }
    }

    // MARK: - Handlers

    private func handleURL(_ attachment: NSItemProvider) async {
        do {
            let item = try await attachment.loadItem(forTypeIdentifier: UTType.url.identifier)
            if let url = item as? URL {
                storeContent(url.absoluteString, sourceType: "shared_url")
            }
        } catch {}
        openHostAppAndFinish()
    }

    private func handleText(_ attachment: NSItemProvider) async {
        do {
            let item = try await attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            if let text = item as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { finish(); return }

                if (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")),
                   URL(string: trimmed) != nil {
                    storeContent(trimmed, sourceType: "shared_url")
                } else {
                    storeContent(trimmed, sourceType: "text")
                }
            }
        } catch {}
        openHostAppAndFinish()
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
                guard !trimmed.isEmpty else { finish(); return }
                storeContent(trimmed, sourceType: "pdf")
            }
        } catch {}
        openHostAppAndFinish()
    }

    // MARK: - Storage

    private func storeContent(_ content: String, sourceType: String) {
        guard let ud = UserDefaults(suiteName: Const.groupID) else { return }
        ud.set(content, forKey: Const.contentKey)
        ud.set(sourceType, forKey: Const.sourceTypeKey)
        ud.set(Date(), forKey: Const.dateKey)
        ud.synchronize()
    }

    // MARK: - Open Main App

    private func openHostAppAndFinish() {
        guard let url = URL(string: Const.schemeURL) else { finish(); return }

        var responder: UIResponder? = self
        while let current = responder {
            if let app = current as? UIApplication {
                app.open(url, options: [:]) { _ in }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.finish()
                }
                return
            }
            responder = current.next
        }
        finish()
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
