import SwiftUI

/// The Pro unlock sheet: one lifetime purchase, no subscriptions.
/// Dark and focused — a single gold moment.
struct PaywallView: View {
    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.plBackground.ignoresSafeArea()

            RadialGradient(colors: [Color.plGold.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.5, y: 0.16),
                           startRadius: 20,
                           endRadius: 440)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                closeRow

                Spacer(minLength: 8)

                hero

                Text("PLATES PRO")
                    .font(.caption.weight(.bold))
                    .tracking(3)
                    .foregroundStyle(Color.plGold)
                    .padding(.top, 30)

                Text("Collect without limits")
                    .font(.plDisplay(32))
                    .foregroundStyle(Color.plText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                featureList
                    .padding(.top, 34)

                Spacer(minLength: 16)

                purchaseButton

                restoreButton
                    .padding(.top, 16)

                Text("One-time purchase. Yours forever.")
                    .font(.footnote)
                    .foregroundStyle(Color.plTextSecondary)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .alert("Purchase Failed", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong. Please try again.")
        }
        .onChange(of: store.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: - Pieces

    private var closeRow: some View {
        HStack {
            Spacer()
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.plTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.plSurfaceElevated))
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, 16)
    }

    private var hero: some View {
        ZStack {
            Circle()
                .strokeBorder(LinearGradient.plGold, lineWidth: 3)
                .frame(width: 128, height: 128)
            Circle()
                .strokeBorder(Color.plGold.opacity(0.35), lineWidth: 1.5)
                .frame(width: 102, height: 102)
            Image(systemName: "fork.knife")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(LinearGradient.plGold)
        }
        .plGlow(.plGold, radius: 18)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 20) {
            featureRow(symbol: "infinity",
                       title: "Unlimited plates",
                       detail: "Collect every restaurant you visit — the ten-plate cap disappears.")
            featureRow(symbol: "chart.bar.fill",
                       title: "Full stats forever",
                       detail: "Every year, every cuisine, every streak, every star you earn.")
            featureRow(symbol: "heart.fill",
                       title: "Support indie development",
                       detail: "One purchase keeps Plates independent and growing.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func featureRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.plSurfaceElevated)
                    .frame(width: 40, height: 40)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.plGold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.plText)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Color.plTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            purchase()
        } label: {
            ZStack {
                Text("Unlock for \(store.priceText)")
                    .opacity(isPurchasing ? 0 : 1)
                if isPurchasing {
                    ProgressView()
                        .tint(Color(hex: 0x14100A))
                }
            }
        }
        .buttonStyle(PlPrimaryButtonStyle())
        .disabled(isPurchasing || isRestoring)
    }

    private var restoreButton: some View {
        Button {
            restore()
        } label: {
            ZStack {
                Text("Restore")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.plTextSecondary)
                    .opacity(isRestoring ? 0 : 1)
                if isRestoring {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.plGold)
                }
            }
        }
        .disabled(isPurchasing || isRestoring)
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Actions

    private func purchase() {
        guard !isPurchasing else { return }
        Haptics.tap()
        isPurchasing = true
        Task { @MainActor in
            defer { isPurchasing = false }
            do {
                if try await store.purchasePro() {
                    Haptics.celebrate()
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        guard !isRestoring else { return }
        Haptics.tap()
        isRestoring = true
        Task { @MainActor in
            await store.restorePurchases()
            isRestoring = false
            if store.isPro {
                Haptics.success()
                dismiss()
            }
        }
    }
}
