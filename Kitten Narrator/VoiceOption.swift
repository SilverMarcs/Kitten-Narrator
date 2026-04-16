import Foundation
import KittenTTS

enum VoiceOption: String, CaseIterable, Identifiable, Sendable {
    case bella, jasper, luna, bruno, rosie, hugo, kiki, leo

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var kittenVoice: KittenVoice {
        switch self {
        case .bella: return .bella
        case .jasper: return .jasper
        case .luna: return .luna
        case .bruno: return .bruno
        case .rosie: return .rosie
        case .hugo: return .hugo
        case .kiki: return .kiki
        case .leo: return .leo
        }
    }

    var gender: String {
        switch self {
        case .bella, .luna, .rosie, .kiki: return "Female"
        case .jasper, .bruno, .hugo, .leo: return "Male"
        }
    }

    var subtitle: String {
        switch self {
        case .bella: return "Warm & Expressive"
        case .jasper: return "Clear & Confident"
        case .luna: return "Soft & Gentle"
        case .bruno: return "Deep & Rich"
        case .rosie: return "Bright & Cheerful"
        case .hugo: return "Strong & Steady"
        case .kiki: return "Light & Playful"
        case .leo: return "Calm & Natural"
        }
    }

    var iconColor: (red: Double, green: Double, blue: Double) {
        switch self {
        case .bella: return (0.95, 0.55, 0.35)
        case .jasper: return (0.35, 0.55, 0.85)
        case .luna: return (0.65, 0.50, 0.85)
        case .bruno: return (0.40, 0.65, 0.50)
        case .rosie: return (0.90, 0.45, 0.55)
        case .hugo: return (0.50, 0.60, 0.70)
        case .kiki: return (0.95, 0.65, 0.75)
        case .leo: return (0.55, 0.70, 0.45)
        }
    }

    static func from(identifier: String) -> VoiceOption {
        VoiceOption(rawValue: identifier) ?? .bella
    }

    static var femaleVoices: [VoiceOption] {
        allCases.filter { $0.gender == "Female" }
    }

    static var maleVoices: [VoiceOption] {
        allCases.filter { $0.gender == "Male" }
    }
}
