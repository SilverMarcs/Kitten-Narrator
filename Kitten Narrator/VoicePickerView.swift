import SwiftUI

struct VoicePickerView: View {
    @Binding var selectedVoice: String
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                section(title: "Feminine", voices: VoiceOption.femaleVoices)
                section(title: "Masculine", voices: VoiceOption.maleVoices)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(backdrop.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Voice")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Header

    private var header: some View {
        let voice = VoiceOption.from(identifier: selectedVoice)
        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(voice.gradient)
                    .frame(width: 92, height: 92)
                    .shadow(color: voice.color.opacity(0.45), radius: 22, y: 10)

                Text(voice.monogram)
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 2) {
                Text(voice.displayName)
                    .font(.title3.bold())
                Text(voice.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .animation(.snappy(duration: 0.3), value: selectedVoice)
    }

    // MARK: - Section

    private func section(title: String, voices: [VoiceOption]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(voices) { voice in
                    VoiceCard(
                        voice: voice,
                        isSelected: selectedVoice == voice.rawValue
                    ) {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedVoice = voice.rawValue
                        }
                    }
                }
            }
        }
    }

    private var backdrop: some View {
        let voice = VoiceOption.from(identifier: selectedVoice)
        return ZStack {
            Color.appBackground
            RadialGradient(
                colors: [voice.color.opacity(0.25), .clear],
                center: .top,
                startRadius: 40,
                endRadius: 400
            )
            .animation(.smooth(duration: 0.6), value: selectedVoice)
        }
    }
}

// MARK: - Voice Card

private struct VoiceCard: View {
    let voice: VoiceOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    ZStack {
                        Circle()
                            .fill(voice.gradient)
                            .frame(width: 44, height: 44)
                        Text(voice.monogram)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? voice.color : .secondary.opacity(0.5))
                        .contentTransition(.symbolEffect(.replace))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(voice.displayName)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(voice.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected
            ? .regular.tint(voice.color.opacity(0.35)).interactive()
            : .regular.interactive(),
            in: .rect(cornerRadius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? voice.color.opacity(0.8) : .clear, lineWidth: 1.5)
        )
        .shadow(color: isSelected ? voice.color.opacity(0.3) : .clear, radius: 14, y: 6)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.snappy(duration: 0.25), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
