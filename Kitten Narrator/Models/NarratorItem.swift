import Foundation
import SwiftData

@Model
final class NarratorItem {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var sourceType: String = "text"
    var sourceURL: String?
    var artworkURL: String?
    var createdAt: Date = Date()
    var isCompleted: Bool = false
    var playbackPosition: Double = 0
    var audioDuration: Double = 0
    var voiceIdentifier: String = "bella"
    var speed: Float = 1.0
    var sortOrder: Int = 0

    init(title: String, content: String, sourceType: String = "text", sourceURL: String? = nil, artworkURL: String? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.sourceType = sourceType
        self.sourceURL = sourceURL
        self.artworkURL = artworkURL
        self.createdAt = Date()
        self.sortOrder = Int(Date().timeIntervalSince1970)
    }

    var audioCacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let audioDir = cacheDir.appendingPathComponent("narrator_audio")
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        return audioDir.appendingPathComponent("\(id.uuidString).wav")
    }

    var wordTimingsCacheURL: URL {
        audioCacheURL.deletingPathExtension().appendingPathExtension("timings.json")
    }

    var hasGeneratedAudio: Bool {
        FileManager.default.fileExists(atPath: audioCacheURL.path)
    }

    var wordCount: Int {
        content.split(separator: " ").count
    }

    var estimatedListenTime: String {
        let rate = max(Double(speed), 0.5)
        let minutes = Double(wordCount) / (150.0 * rate)
        if minutes < 1 { return "< 1 min" }
        return "\(Int(ceil(minutes))) min"
    }

    var sourceIcon: String {
        switch sourceType {
        case "url": return "link"
        case "clipboard": return "doc.on.clipboard"
        case "pdf": return "doc.richtext"
        default: return "text.alignleft"
        }
    }

    var progressPercentage: Double {
        guard audioDuration > 0 else { return 0 }
        return min(playbackPosition / audioDuration, 1.0)
    }
}
