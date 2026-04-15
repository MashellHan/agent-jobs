import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState
    let onTakeBreak: () -> Void
    @Binding var showMascot: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusSection
            Divider()
            statsSection
            Divider()
            modeSection
            Divider()
            mascotSection
            Divider()
            actionSection
        }
        .padding(12)
        .frame(width: 260)
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

            lastBreakRow
        }
    }

    private var lastBreakRow: some View {
        HStack {
            Image(systemName: "arrow.counterclockwise")
                .foregroundStyle(.secondary)
            Text("Last break: \(lastBreakText)")
                .font(.system(size: 12))
        }
    }

    private var lastBreakText: String {
        guard let lastBreak = appState.lastBreakTime else {
            return "none yet"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastBreak, relativeTo: .now)
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Reminder Mode")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Picker("Mode", selection: $appState.reminderMode) {
                ForEach(ReminderMode.allCases, id: \.self) { mode in
                    Text(mode.displayName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(appState.reminderMode.description)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Mascot Section

    private var mascotSection: some View {
        Toggle(isOn: $showMascot) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                Text("Show Eye Guardian")
                    .font(.system(size: 12))
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
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
