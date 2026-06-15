import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var settings = Settings.shared
    var onBack: () -> Void
    var showPaywall: () -> Void

    private var theme: AppTheme { settings.theme }
    private var store: ReminderStore { model.store }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
                Text("Settings").font(.headline)
                Spacer()
            }

            // Sound toggle (Pro-locked)
            HStack {
                Toggle("Play a sound with reminders", isOn: Binding(
                    get: { settings.playSound },
                    set: { newValue in
                        if model.isPro {
                            settings.playSound = newValue
                            store.reschedule()  // re-emit notifications with/without sound
                        } else { showPaywall() }
                    }
                ))
                .font(.system(size: 13))
                .disabled(!model.isPro)
                if !model.isPro {
                    Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(theme.accent)
                }
            }

            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .font(.system(size: 13))

            // Custom intervals (Pro)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Intervals").font(.caption).foregroundStyle(.secondary)
                    if !model.isPro {
                        Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(theme.accent)
                    }
                }
                ForEach(ReminderKind.allCases) { kind in
                    HStack(spacing: 8) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(kind.title).font(.system(size: 12))
                        Spacer()
                        if model.canEditInterval {
                            Stepper(value: Binding(
                                get: { store.minutes(kind) },
                                set: { model.setMinutes(kind, $0) }
                            ), in: 1...240, step: 5) {
                                Text("\(store.minutes(kind)) min")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button {
                                showPaywall()
                            } label: {
                                HStack(spacing: 3) {
                                    Text("\(store.minutes(kind)) min")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }

            // Theme picker (Aurora free, others Pro)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("Theme").font(.caption).foregroundStyle(.secondary)
                    if !model.isPro {
                        Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(theme.accent)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(AppTheme.allCases) { t in
                        Button {
                            if model.isPro || t == .aurora { settings.themeID = t.rawValue }
                            else { showPaywall() }
                        } label: {
                            Circle()
                                .fill(LinearGradient(colors: t.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(.white, lineWidth: settings.themeID == t.rawValue ? 2 : 0))
                                .overlay(alignment: .bottomTrailing) {
                                    if !model.isPro && t != .aurora {
                                        Image(systemName: "lock.fill").font(.system(size: 7)).foregroundStyle(.white)
                                    }
                                }
                        }.buttonStyle(.plain)
                    }
                }
            }

            // Notification permission status
            HStack(spacing: 6) {
                Image(systemName: store.authorized ? "bell.fill" : "bell.slash.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(store.authorized ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.secondary))
                Text(store.authorized ? "Notifications enabled" : "Notifications off")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if !store.authorized {
                    Button("Enable") {
                        Task { await store.requestAuthIfNeeded(); store.reschedule() }
                    }.buttonStyle(.link).font(.caption)
                }
            }

            Divider()

            HStack {
                Text(model.isPro ? "Pausely Pro · active" : "Free version")
                    .font(.caption).foregroundStyle(model.isPro ? theme.accent : Color.secondary)
                Spacer()
                if !model.isPro {
                    Button("Restore") { Task { await model.entitlements.restore() } }
                        .buttonStyle(.link).font(.caption)
                }
            }
        }
        .padding(16)
    }
}
