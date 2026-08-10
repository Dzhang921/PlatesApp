import SwiftUI
import SwiftData

/// The settings card at the bottom of the Passport screen: home currency,
/// purchase restore, and app info — plus developer rows in debug builds.
struct SettingsSection: View {
    var restaurants: [Restaurant]

    @Environment(\.modelContext) private var context
    @Environment(StoreService.self) private var store

    @State private var homeCurrency = CurrencyConverter.homeCurrency
    @State private var isRestoring = false
    @State private var showRestoreResult = false
    @State private var restoreMessage = ""
    #if DEBUG
    @State private var showResetConfirmation = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SETTINGS")
                .font(.footnote.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Color.plTextSecondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                currencyRow
                divider
                restoreRow
                divider
                aboutRow
                #if DEBUG
                if restaurants.isEmpty {
                    divider
                    loadSampleRow
                }
                divider
                resetRow
                #endif
            }
            .plCard(padding: 0)
        }
        .onChange(of: homeCurrency) { _, newCode in
            applyHomeCurrency(newCode)
        }
        .alert("Restore Purchases", isPresented: $showRestoreResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage)
        }
        #if DEBUG
        .confirmationDialog("Reset all data?",
                            isPresented: $showResetConfirmation,
                            titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes every restaurant, visit, and photo, and clears all badges. This cannot be undone.")
        }
        #endif
    }

    // MARK: - Rows

    private var currencyRow: some View {
        HStack(spacing: 12) {
            rowIcon("banknote")
            Text("Home currency")
                .foregroundStyle(Color.plText)
            Spacer()
            Menu {
                Picker("Home currency", selection: $homeCurrency) {
                    ForEach(CurrencyConverter.supportedCurrencies, id: \.self) { code in
                        Text("\(code) · \(trimmedSymbol(for: code))").tag(code)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text("\(trimmedSymbol(for: homeCurrency)) \(homeCurrency)")
                        .font(.plNumber(15, weight: .semibold))
                        .foregroundStyle(Color.plGold)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.plTextSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var restoreRow: some View {
        Button {
            restore()
        } label: {
            HStack(spacing: 12) {
                rowIcon("arrow.clockwise")
                Text("Restore Purchases")
                    .foregroundStyle(Color.plText)
                Spacer()
                if isRestoring {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.plGold)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.plTextSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
    }

    private var aboutRow: some View {
        HStack(spacing: 12) {
            rowIcon("info.circle")
            Text("About")
                .foregroundStyle(Color.plText)
            Spacer()
            Text("Plates \(versionText)")
                .font(.footnote)
                .foregroundStyle(Color.plTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    #if DEBUG
    private var loadSampleRow: some View {
        Button {
            Haptics.success()
            SampleData.load(into: context)
        } label: {
            HStack(spacing: 12) {
                rowIcon("sparkles")
                Text("Load Sample Collection")
                    .foregroundStyle(Color.plText)
                Spacer()
                debugTag
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var resetRow: some View {
        Button {
            Haptics.tap()
            showResetConfirmation = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(width: 26)
                Text("Reset All Data")
                    .foregroundStyle(.red)
                Spacer()
                debugTag
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var debugTag: some View {
        Text("DEBUG")
            .font(.caption2.weight(.bold))
            .tracking(1)
            .foregroundStyle(Color.plTextSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.plSurfaceElevated))
    }
    #endif

    private var divider: some View {
        Rectangle()
            .fill(Color.plStroke)
            .frame(height: 1)
            .padding(.leading, 54)
    }

    private func rowIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.plTextSecondary)
            .frame(width: 26)
    }

    // MARK: - Actions

    private var versionText: String {
        let version = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        if let build = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            return "\(version) (\(build))"
        }
        return version
    }

    private func trimmedSymbol(for code: String) -> String {
        CurrencyConverter.symbol(for: code)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Switches the home currency and re-converts every stored visit amount
    /// from its original receipt currency, so history follows the new home.
    private func applyHomeCurrency(_ code: String) {
        guard code != CurrencyConverter.homeCurrency else { return }
        CurrencyConverter.homeCurrency = code
        for restaurant in restaurants {
            for visit in restaurant.visits {
                visit.amountHome = CurrencyConverter.toHome(visit.amount,
                                                           from: visit.currencyCode)
            }
        }
        try? context.save()
        WidgetSnapshotWriter.write(restaurants: restaurants)
        Haptics.success()
    }

    private func restore() {
        guard !isRestoring else { return }
        Haptics.tap()
        isRestoring = true
        Task { @MainActor in
            await store.restorePurchases()
            isRestoring = false
            restoreMessage = store.isPro
                ? "Plates Pro is active on this Apple Account."
                : "No previous purchases were found."
            showRestoreResult = true
        }
    }

    #if DEBUG
    /// Deletes the entire collection, removes every stored image, and clears
    /// badge + spotlight state so the app returns to a first-launch canvas.
    private func resetAllData() {
        for restaurant in restaurants {
            for visit in restaurant.visits {
                if let path = visit.receiptImagePath {
                    ImageStore.delete(path)
                }
                for path in visit.foodPhotoPaths {
                    ImageStore.delete(path)
                }
            }
            context.delete(restaurant)
        }
        try? context.save()
        UserDefaults.standard.removeObject(forKey: "earnedBadgeIDs")
        UserDefaults.standard.removeObject(forKey: "pendingSpotlightID")
        WidgetSnapshotWriter.write(restaurants: [])
        Haptics.success()
    }
    #endif
}
