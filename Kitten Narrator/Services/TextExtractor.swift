import Foundation

enum TextExtractor {
    struct Result {
        let title: String?
        let content: String
    }

    static func extractFromHTML(_ html: String) -> Result {
        let title = extractTitle(from: html)

        var text = html

        let removeTags = ["script", "style", "nav", "header", "footer", "aside", "noscript"]
        for tag in removeTags {
            text = text.replacingOccurrences(
                of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        let blockTags = ["p", "div", "br", "h1", "h2", "h3", "h4", "h5", "h6", "li", "tr", "blockquote", "article", "section"]
        for tag in blockTags {
            text = text.replacingOccurrences(
                of: "</?\(tag)[^>]*>",
                with: "\n",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"),
            ("&nbsp;", " "), ("&mdash;", "\u{2014}"), ("&ndash;", "\u{2013}"),
            ("&hellip;", "\u{2026}"), ("&lsquo;", "\u{2018}"), ("&rsquo;", "\u{2019}"),
            ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }

        text = text.replacingOccurrences(
            of: "&#(\\d+);",
            with: "",
            options: .regularExpression
        )
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let range = NSRange(text.startIndex..., in: text)
            let results = regex.matches(in: text, range: range)
            for match in results.reversed() {
                if let numRange = Range(match.range(at: 1), in: text),
                   let code = UInt32(text[numRange]),
                   let scalar = Unicode.Scalar(code) {
                    let charRange = Range(match.range, in: text)!
                    text.replaceSubrange(charRange, with: String(scalar))
                }
            }
        }

        text = text.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n[ \\t]+", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return Result(title: title, content: text)
    }

    private static func extractTitle(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let contentRange = Range(match.range(at: 1), in: html)
        else { return nil }

        let title = String(html[contentRange])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
}
