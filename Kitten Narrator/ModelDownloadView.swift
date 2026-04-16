import SwiftUI

struct ModelDownloadView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.orange.opacity(0.1))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(.orange.opacity(0.08))
                    .frame(width: 180, height: 180)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.orange)
                    .symbolEffect(.breathe)
            }

            VStack(spacing: 12) {
                Text("Setting Up Narrator")
                    .font(.title.bold())

                Text("Downloading the speech engine.\nThis only happens once.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                ProgressView(value: progress)
                    .tint(.orange)
                    .frame(maxWidth: 240)

                Text("\(Int(progress * 100))%")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Spacer()
        }
        .padding(32)
    }
}
