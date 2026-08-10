import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// The app's signature screen: a realistic globe at night where every collected
/// plate is a point of light. Handles the post-capture "light up" spotlight.
struct GlobeView: View {
    @Query(sort: \Restaurant.addedAt, order: .reverse) private var restaurants: [Restaurant]

    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                  distance: GlobeView.globeDistance)
    )
    @State private var selectedRestaurant: Restaurant?
    @State private var bloomToken: UUID?
    @State private var hasPositionedCamera = false
    @State private var spotlightTask: Task<Void, Never>?

    private static let globeDistance: Double = 35_000_000
    private static let swingDistance: Double = 2_600_000
    private static let spotlightDistance: Double = 4_000

    init() {}

    var body: some View {
        ZStack(alignment: .top) {
            globeMap
                .ignoresSafeArea()

            topScrim

            headerOverlay
        }
        .overlay {
            if restaurants.isEmpty {
                emptyState
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay {
            if let bloomToken {
                SpotlightBloom()
                    .id(bloomToken)
            }
        }
        .sheet(item: $selectedRestaurant) { restaurant in
            RestaurantPreviewSheet(restaurant: restaurant)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.plSurface)
        }
        .onAppear {
            positionCameraIfNeeded()
            checkSpotlight()
        }
        .onChange(of: restaurants.count) {
            checkSpotlight()
        }
        .onDisappear {
            spotlightTask?.cancel()
            spotlightTask = nil
        }
    }

    // MARK: - Map

    private var globeMap: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            ForEach(restaurants) { restaurant in
                Annotation(restaurant.name, coordinate: restaurant.coordinate, anchor: .center) {
                    GlobeAnnotationDot(isMichelin: restaurant.isMichelin,
                                       visitCount: restaurant.visitCount)
                        .onTapGesture {
                            Haptics.tap()
                            selectedRestaurant = restaurant
                        }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControlVisibility(.hidden)
    }

    // MARK: - Overlays

    private var topScrim: some View {
        LinearGradient(colors: [Color.plBackground.opacity(0.85),
                                Color.plBackground.opacity(0.45),
                                Color.plBackground.opacity(0)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 210)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }

    private var headerOverlay: some View {
        VStack(spacing: 12) {
            Text("Your World")
                .font(.plDisplay(30))
                .foregroundStyle(Color.plText)
                .shadow(color: Color.plBackground.opacity(0.7), radius: 10)

            statsStrip
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var statsStrip: some View {
        let stats = StatsEngine.lifetime(restaurants: restaurants)
        return HStack(spacing: 10) {
            statItem(value: "\(stats.plateCount)",
                     label: stats.plateCount == 1 ? "plate" : "plates")
            separatorDot
            statItem(value: "\(stats.countryCount)",
                     label: stats.countryCount == 1 ? "country" : "countries")
            separatorDot
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.plMichelin)
                Text("\(stats.michelinStarsCollected)")
                    .font(.plNumber(14))
                    .foregroundStyle(Color.plText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Color.plStroke.opacity(0.8), lineWidth: 1))
    }

    private func statItem(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.plNumber(14))
                .foregroundStyle(Color.plText)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)
        }
    }

    private var separatorDot: some View {
        Circle()
            .fill(Color.plTextSecondary.opacity(0.6))
            .frame(width: 3, height: 3)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(LinearGradient.plGold)
                .plGlow(.plGold, radius: 10)
            Text("Your globe is dark")
                .font(.plDisplay(24))
                .foregroundStyle(Color.plText)
            Text("Scan your first receipt to light it up.")
                .font(.system(size: 15))
                .foregroundStyle(Color.plTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.plStroke, lineWidth: 1))
        .padding(.horizontal, 44)
    }

    // MARK: - Camera

    private func positionCameraIfNeeded() {
        guard !hasPositionedCamera else { return }
        hasPositionedCamera = true
        cameraPosition = .camera(MapCamera(centerCoordinate: platesCentroid,
                                           distance: Self.globeDistance))
    }

    private var platesCentroid: CLLocationCoordinate2D {
        guard !restaurants.isEmpty else {
            return CLLocationCoordinate2D(latitude: 20, longitude: 0)
        }
        let count = Double(restaurants.count)
        let lat = restaurants.reduce(0.0) { $0 + $1.latitude } / count
        let lon = restaurants.reduce(0.0) { $0 + $1.longitude } / count
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // MARK: - Spotlight (post-capture light-up)

    private func checkSpotlight() {
        guard let idString = UserDefaults.standard.string(forKey: "pendingSpotlightID"),
              let id = UUID(uuidString: idString),
              let target = restaurants.first(where: { $0.id == id }) else { return }
        UserDefaults.standard.removeObject(forKey: "pendingSpotlightID")
        flyTo(target)
    }

    private func flyTo(_ restaurant: Restaurant) {
        let coordinate = restaurant.coordinate
        selectedRestaurant = nil
        spotlightTask?.cancel()
        spotlightTask = Task { @MainActor in
            // Stage 1: swing the globe so the target faces the camera, still in orbit.
            withAnimation(.easeInOut(duration: 1.2)) {
                cameraPosition = .camera(MapCamera(centerCoordinate: coordinate,
                                                   distance: Self.swingDistance))
            }
            try? await Task.sleep(for: .seconds(1.3))
            if Task.isCancelled { return }

            // Stage 2: dive down to street level over the restaurant.
            withAnimation(.easeInOut(duration: 1.15)) {
                cameraPosition = .camera(MapCamera(centerCoordinate: coordinate,
                                                   distance: Self.spotlightDistance))
            }
            try? await Task.sleep(for: .seconds(1.25))
            if Task.isCancelled { return }

            playBloom()
        }
    }

    private func playBloom() {
        let token = UUID()
        bloomToken = token
        Haptics.celebrate()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.3))
            if bloomToken == token { bloomToken = nil }
        }
    }
}

// MARK: - Bloom

/// A one-shot expanding gold ring + glow played center-screen when a new plate
/// lights up (the fly-to camera centers the target, so center-screen is exact).
private struct SpotlightBloom: View {
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.plGold.opacity(0.45),
                                              Color.plGold.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 220)
                .scaleEffect(expanded ? 1.9 : 0.15)
                .opacity(expanded ? 0 : 0.9)

            Circle()
                .strokeBorder(LinearGradient.plGold, lineWidth: 2.5)
                .frame(width: 84, height: 84)
                .plGlow(.plGold, radius: 16)
                .scaleEffect(expanded ? 3.1 : 0.15)
                .opacity(expanded ? 0 : 1)

            Circle()
                .fill(LinearGradient.plGold)
                .frame(width: 14, height: 14)
                .plGlow(.plGold, radius: 14)
                .scaleEffect(expanded ? 1.6 : 0.3)
                .opacity(expanded ? 0 : 1)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                expanded = true
            }
        }
    }
}
