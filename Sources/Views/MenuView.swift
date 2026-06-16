import SwiftUI

struct MenuView: View {
    @EnvironmentObject var model: AppModel
    @State private var showPaywall = false
    @State private var showSettings = false

    private var theme: AppTheme { model.settings.theme }
    private var store: ReminderStore { model.store }

    var body: some View {
        VStack(spacing: 0) {
            if showPaywall {
                PaywallView(onClose: { showPaywall = false })
                    .environmentObject(model)
            } else if showSettings {
                SettingsView(onBack: { showSettings = false },
                             showPaywall: { showSettings = false; showPaywall = true })
                    .environmentObject(model)
            } else {
                main
            }
        }
        .frame(width: 320)
    }

    private var main: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Text("Pausely").font(.headline)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            heroCard

            if !store.authorized && store.anyEnabled {
                permissionNote
            }

            // Reminder rows
            VStack(spacing: 8) {
                ForEach(ReminderKind.allCases) { kind in
                    reminderRow(kind)
                }
            }

            statsStrip

            Divider()

            if !model.isPro {
                Button(action: { showPaywall = true }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Unlock Pausely Pro").bold()
                        Spacer()
                        if !model.entitlements.priceText.isEmpty {
                            Text(model.entitlements.priceText).font(.caption).opacity(0.9)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9).padding(.horizontal, 12)
                    .background(LinearGradient(colors: theme.gradient, startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(.plain)
            }

            HStack {
                Button("Settings") { showSettings = true }.buttonStyle(.link)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.link)
            }
            .font(.caption)
        }
        .padding(16)
    }

    // MARK: - Hero card (next break countdown)

    private var heroCard: some View {
        VStack(spacing: 6) {
            if let next = store.nextBreak {
                Image(systemName: next.kind.symbol)
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                Text(store.nextBreakText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("Next: \(next.kind.title)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
                Text("No reminders on")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Turn one on below to start")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(store.anyEnabled
                      ? AnyShapeStyle(LinearGradient(colors: theme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color.primary.opacity(0.06)))
        )
    }

    // MARK: - Reminder row

    private func reminderRow(_ kind: ReminderKind) -> some View {
        let enabled = store.isEnabled(kind)
        let mins = store.minutes(kind)
        return HStack(spacing: 11) {
            Image(systemName: kind.symbol)
                .foregroundStyle(enabled ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.secondary))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title).font(.system(size: 13, weight: .semibold))
                Button {
                    // Editing the interval is Pro-only.
                    if model.canEditInterval { /* see Settings for editing */ }
                    else { showPaywall = true }
                } label: {
                    HStack(spacing: 3) {
                        Text("every \(mins) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !model.isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { enabled },
                set: { newValue in
                    if !model.toggle(kind, to: newValue) {
                        // Blocked by the free single-reminder rule.
                        showPaywall = true
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(theme.accent)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Today stats strip

    private var statsStrip: some View {
        HStack(spacing: 4) {
            Text("Today").font(.caption).foregroundStyle(.secondary)
            Spacer()
            if model.isPro {
                Text("\(store.todayTotal) breaks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.accent)
                    Text("•• breaks")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .blur(radius: 2.5)
                }
                .onTapGesture { showPaywall = true }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Permission note

    private var permissionNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Notifications are off — you'll only see the in-app timer.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Enable") {
                Task { await store.requestAuthIfNeeded(); store.reschedule() }
            }
            .buttonStyle(.link)
            .font(.caption2)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
