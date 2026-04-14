import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let onTakeBreak: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusSection
            Divider()
            statsSection
            Divider()
            actionSection
        }
        .padding(12)
        .frame(width: 240)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appState.statusColor.color)
                .frame(width: 10, height: 10)

            Text(appState.statusColor.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text("Screen time: \(appState.formattedTimeSinceBreak)")
                    .font(.system(size: 12))
            }

            HStack {
                Image(systemName: "eye")
                    .foregroundStyle(.secondary)
                Text("Breaks today: \(appState.breaksTakenToday)")
                    .font(.system(size: 12))
            }
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: 4) {
            Button(action: onTakeBreak) {
                HStack {
                    Image(systemName: "eye.trianglebadge.exclamationmark")
                    Text("Take a Break Now")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Quit EyesHealth")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }
}
