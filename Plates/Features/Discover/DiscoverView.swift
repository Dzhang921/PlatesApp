import CoreLocation
import MapKit
import SwiftData
import SwiftUI

/// The Discover tab — Plates reads the collection, learns the user's taste,
/// and suggests where to eat next in any city (or right where they're standing).
/// Candidates come from the bundled Michelin Guide and Apple Maps; reasons are
/// written on-device.
struct DiscoverView: View {
    @Query(sort: \Restaurant.addedAt) private var restaurants: [Restaurant]

    @State private var cityQuery = ""
    @State private var cityResults: [CityMatch] = []
    @State private var selectedCity: CityMatch?
    @State private var recommendations: [Recommendation]?
    @State private var isRecommending = false
    @State private var isLocating = false

    @State private var citySearchTask: Task<Void, Never>?
    @State private var recommendTask: Task<Void, Never>?
    @State private var locateTask: Task<Void, Never>?

    /// Recommendations unlock once the profile has this many plates to read.
    private let minimumPlates = 3

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if profile.plateCount < minimumPlates {
                        DiscoverTeaserCard(plateCount: profile.plateCount, needed: minimumPlates)
                    } else {
                        DiscoverTasteCard(profile: profile, starsCollected: starsCollected)
                        citySection
                        resultsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color.plBackground.ignoresSafeArea())
            .navigationTitle("Discover")
            #if DEBUG
            // Headless verification hook: -autoDiscoverCity "Tokyo" searches the
            // city and runs the full recommendation pipeline on launch.
            .task {
                guard let query = UserDefaults.standard.string(forKey: "autoDiscoverCity"),
                      !query.isEmpty, selectedCity == nil else { return }
                if let city = await TasteEngine.searchCities(query).first {
                    select(city)
                }
            }
            #endif
        }
    }

    // MARK: - Data

    private var profile: TasteProfile {
        TasteEngine.profile(restaurants: restaurants)
    }

    /// Collection semantic: each distinct restaurant counts its stars once.
    private var starsCollected: Int {
        restaurants.reduce(0) { $0 + max(0, $1.michelinStars) }
    }

    // MARK: - City picker

    private var citySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DiscoverSectionLabel("Next destination")

            HStack(spacing: 10) {
                searchField
                nearMeChip
            }

            if !cityResults.isEmpty {
                cityResultsCard
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)

            TextField("Where are you headed?", text: $cityQuery)
                .font(.system(size: 15))
                .foregroundStyle(Color.plText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.search)

            if !cityQuery.isEmpty {
                Button {
                    cityQuery = ""
                    cityResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.plTextSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.plSurface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.plStroke, lineWidth: 1))
        .onChange(of: cityQuery) { _, newValue in
            searchCities(newValue)
        }
    }

    private var nearMeChip: some View {
        Button {
            useNearMe()
        } label: {
            HStack(spacing: 5) {
                if isLocating {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Color(hex: 0x14100A))
                } else {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text("Near me")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color(hex: 0x14100A))
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(Capsule().fill(LinearGradient.plGold))
        }
        .buttonStyle(.plain)
        .disabled(isLocating)
    }

    private var cityResultsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(cityResults.enumerated()), id: \.element.id) { index, city in
                Button {
                    select(city)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.plGold)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(city.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.plText)
                                .lineLimit(1)
                            if !city.country.isEmpty {
                                Text(city.country)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.plTextSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.plTextSecondary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < cityResults.count - 1 {
                    Divider()
                        .overlay(Color.plStroke.opacity(0.7))
                }
            }
        }
        .plCard(padding: 14)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        if let city = selectedCity {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    DiscoverSectionLabel("Picked for you")
                    Spacer(minLength: 8)
                    Text(cityLabel(city))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.plGold)
                        .lineLimit(1)
                }

                if isRecommending {
                    DiscoverLoadingCard()
                } else if let recommendations {
                    if recommendations.isEmpty {
                        DiscoverEmptyResultsCard(cityName: city.name)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, recommendation in
                                DiscoverRecommendationCard(rank: index + 1,
                                                           recommendation: recommendation) {
                                    open(recommendation)
                                }
                            }
                        }
                        footer
                    }
                }
            }
        }
    }

    private var footer: some View {
        Text("Candidates from the Michelin Guide and Apple Maps. Reasons generated on your iPhone.")
            .font(.system(size: 11))
            .foregroundStyle(Color.plTextSecondary.opacity(0.8))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    private func cityLabel(_ city: CityMatch) -> String {
        city.country.isEmpty ? city.name : "\(city.name), \(city.country)"
    }

    // MARK: - Actions

    private func searchCities(_ query: String) {
        citySearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            cityResults = []
            return
        }
        citySearchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let results = await TasteEngine.searchCities(trimmed)
            guard !Task.isCancelled else { return }
            cityResults = results
        }
    }

    private func select(_ city: CityMatch) {
        Haptics.tap()
        cityQuery = ""
        cityResults = []
        selectedCity = city
        recommendations = nil

        // Switching city cancels whatever was in flight.
        recommendTask?.cancel()
        isRecommending = true

        let profile = self.profile
        let existing = Array(restaurants)
        recommendTask = Task {
            let recommendations = await TasteEngine.recommend(in: city,
                                                              profile: profile,
                                                              existing: existing)
            guard !Task.isCancelled else { return }
            self.recommendations = recommendations
            isRecommending = false
            Haptics.success()
        }
    }

    private func useNearMe() {
        Haptics.tap()
        isLocating = true
        LocationProvider.shared.request()

        locateTask?.cancel()
        locateTask = Task {
            // The provider is one-shot and silent on denial — poll briefly,
            // then give up quietly.
            var coordinate = LocationProvider.shared.lastCoordinate
            var attempts = 0
            while coordinate == nil, attempts < 16, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                coordinate = LocationProvider.shared.lastCoordinate
                attempts += 1
            }
            guard !Task.isCancelled else { return }
            guard let coordinate else {
                isLocating = false
                return
            }

            let location = CLLocation(latitude: coordinate.latitude,
                                      longitude: coordinate.longitude)
            let placemarks = (try? await CLGeocoder().reverseGeocodeLocation(location)) ?? []
            guard !Task.isCancelled else { return }
            isLocating = false

            let placemark = placemarks.first
            let name = placemark?.locality
                ?? placemark?.subAdministrativeArea
                ?? placemark?.administrativeArea
                ?? "Around you"
            select(CityMatch(name: name,
                             country: placemark?.country ?? "",
                             latitude: coordinate.latitude,
                             longitude: coordinate.longitude))
        }
    }

    private func open(_ recommendation: Recommendation) {
        Haptics.tap()
        let location = CLLocation(latitude: recommendation.latitude,
                                  longitude: recommendation.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = recommendation.name
        item.openInMaps()
    }
}
