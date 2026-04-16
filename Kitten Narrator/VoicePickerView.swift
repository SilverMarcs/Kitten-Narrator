import SwiftUI

struct VoicePickerView: View {
    @Binding var selectedVoice: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(VoiceOption.femaleVoices) { voice in
                    voiceRow(voice)
                }
            } header: {
                Text("Female")
            }

            Section {
                ForEach(VoiceOption.maleVoices) { voice in
                    voiceRow(voice)
                }
            } header: {
                Text("Male")
            }
        }
        .navigationTitle("Voice")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func voiceRow(_ voice: VoiceOption) -> some View {
        let isSelected = selectedVoice == voice.rawValue
        let color = Color(
            red: voice.iconColor.red,
            green: voice.iconColor.green,
            blue: voice.iconColor.blue
        )

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedVoice = voice.rawValue
            }
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 44, height: 44)

                    Text(String(voice.displayName.prefix(1)))
                        .font(.headline.bold())
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(voice.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(voice.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
