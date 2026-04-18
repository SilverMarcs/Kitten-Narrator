import Foundation

func formatDuration(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

func formatSpeed(_ speed: Double) -> String {
    if abs(speed - floor(speed)) < 0.001 { return "\(Int(speed))×" }
    return String(format: "%.2g×", speed)
}
