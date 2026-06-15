import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var theme: AppTheme { model.settings.theme }

    private let benefits: [(String, String, String)] = [
        ("infinity", "All reminders at once", "Eyes, posture, water & stretch together"),
        ("slider.horizontal.3", "Custom intervals", "Tune each reminder to your rhythm"),
        ("chart.bar.fill", "Daily stats", "See how many breaks you take"),
        ("speaker.wave.2.fill", "Sounds & themes", "Pick your sound and all themes"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Image(systemName: "crown.fill").font(.system(size: 34)).foregroundStyle(.white)
                    Text("Pausely Pro").font(.title2.bold()).foregroundStyle(.white)
                    Text("One-time purchase — unlock everything")
                        .font(.caption).foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(LinearGradient(colors: theme.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))

                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.85))
                }.buttonStyle(.plain).padding(10)
            }

            VStack(alignment: .leading, spacing: 13) {
                ForEach(benefits, id: \.0) { b in
                    HStack(spacing: 11) {
                        Image(systemName: b.0).foregroundStyle(theme.accent).frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(b.1).font(.system(size: 13, weight: .semibold))
                            Text(b.2).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(18)

            VStack(spacing: 8) {
                if let err = model.entitlements.lastError {
                    Text(err).font(.caption2).foregroundStyle(.red).lineLimit(2)
                }
                Button {
                    Task { await model.entitlements.purchase(); if model.isPro { dismiss() } }
                } label: {
                    HStack {
                        if model.entitlements.purchasing { ProgressView().controlSize(.small) }
                        Text(buyLabel).bold()
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(theme.accent).controlSize(.large)
                .disabled(model.entitlements.purchasing)

                Button("Restore purchase") { Task { await model.entitlements.restore(); if model.isPro { dismiss() } } }
                    .buttonStyle(.link).font(.caption)

                Text("One-time payment, billed to your App Store account.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 18).padding(.bottom, 16)
        }
        .frame(width: 340)
    }

    private var buyLabel: String {
        let price = model.entitlements.priceText
        return price.isEmpty ? "Unlock Pro" : "Unlock Pro · \(price)"
    }
}
