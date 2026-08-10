import SwiftUI
import SwiftData

@main
struct PlatesApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Restaurant.self, Visit.self)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(.plGold)
        }
        .modelContainer(container)
    }
}

enum AppTab: Hashable {
    case globe, collection, stats, discover, passport
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @State private var store = StoreService.shared
    @State private var showCapture = false
    @State private var showPaywallDebug = false
    @State private var tab: AppTab = .globe

    #if DEBUG
    // Launch-argument hooks so the app can be driven headlessly from
    // `simctl launch` (e.g. -initialTab stats -autoloadSampleData YES).
    init() {
        switch UserDefaults.standard.string(forKey: "initialTab") {
        case "collection": _tab = State(initialValue: .collection)
        case "stats": _tab = State(initialValue: .stats)
        case "discover": _tab = State(initialValue: .discover)
        case "passport": _tab = State(initialValue: .passport)
        default: break
        }
    }
    #endif

    var body: some View {
        ZStack {
            if hasOnboarded {
                mainView.transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) { hasOnboarded = true }
                }
                .transition(.opacity)
            }
        }
        .environment(store)
        .task {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "autoloadSampleData"), restaurants.isEmpty {
                SampleData.load(into: modelContext)
            }
            if UserDefaults.standard.bool(forKey: "autoshowCapture") {
                showCapture = true
            }
            if UserDefaults.standard.bool(forKey: "autoshowPaywall") {
                showPaywallDebug = true
            }
            #endif
            await store.start()
            WidgetSnapshotWriter.write(restaurants: restaurants)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                WidgetSnapshotWriter.write(restaurants: restaurants)
            }
        }
    }

    private var mainView: some View {
        TabView(selection: $tab) {
            Tab("Globe", systemImage: "globe.americas.fill", value: AppTab.globe) { GlobeView() }
            Tab("Collection", systemImage: "square.grid.2x2.fill", value: AppTab.collection) { CollectionView() }
            Tab("Stats", systemImage: "chart.bar.fill", value: AppTab.stats) { StatsView() }
            Tab("Discover", systemImage: "sparkles", value: AppTab.discover) { DiscoverView() }
            Tab("Passport", systemImage: "book.closed.fill", value: AppTab.passport) { PassportView() }
        }
        .overlay(alignment: .bottomTrailing) {
            captureButton
                .padding(.trailing, 20)
                .padding(.bottom, 92)
        }
        .sheet(isPresented: $showPaywallDebug) { PaywallView() }
        .fullScreenCover(isPresented: $showCapture, onDismiss: {
            WidgetSnapshotWriter.write(restaurants: restaurants)
            // The capture flow sets pendingSpotlightID after saving a new
            // restaurant; the Globe picks it up and plays the light-up moment.
            if UserDefaults.standard.string(forKey: "pendingSpotlightID") != nil {
                tab = .globe
            }
        }) {
            CaptureFlowView()
        }
    }

    private var captureButton: some View {
        Button {
            Haptics.tap()
            showCapture = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(hex: 0x14100A))
                .frame(width: 58, height: 58)
                .background(Circle().fill(LinearGradient.plGold))
                .plGlow(.plGold, radius: 14)
        }
        .accessibilityLabel("Add a receipt")
    }
}
