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
        case .bella:  return (0.98, 0.50, 0.25)
        case .kiki:   return (0.98, 0.76, 0.22)
        case .leo:    return (0.28, 0.72, 0.42)
        case .bruno:  return (0.12, 0.68, 0.62)
        case .jasper: return (0.22, 0.58, 0.96)
        case .hugo:   return (0.34, 0.38, 0.82)
        case .luna:   return (0.62, 0.48, 0.94)
        case .rosie:  return (0.95, 0.28, 0.60)
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
