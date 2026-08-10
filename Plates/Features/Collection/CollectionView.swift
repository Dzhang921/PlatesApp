import SwiftUI
import SwiftData

/// The collection tab: every plate you've earned, searchable and filterable,
/// laid out as a two-column grid of PlateCards.
struct CollectionView: View {
    @Query(sort: \Restaurant.addedAt, order: .reverse) private var restaurants: [Restaurant]

    @State private var searchText = ""
    @State private var sort: CollectionSortOption = .recent
    @State private var selectedCuisine: Cuisine?

    private var plateCountText: String {
        "\(restaurants.count) plate\(restaurants.count == 1 ? "" : "s")"
    }

    private var cuisinesPresent: [(cuisine: Cuisine, count: Int)] {
        var counts: [Cuisine: Int] = [:]
        for restaurant in restaurants {
            counts[restaurant.cuisine, default: 0] += 1
        }
        return counts
            .map { (cuisine: $0.key, count: $0.value) }
            .sorted {
                $0.count == $1.count
                    ? $0.cuisine.displayName < $1.cuisine.displayName
                    : $0.count > $1.count
            }
    }

    private var visiblePlates: [Restaurant] {
        var list = restaurants
        if sort == .michelinOnly {
            list = list.filter(\.isMichelin)
        }
        if let cuisine = selectedCuisine {
            list = list.filter { $0.cuisine == cuisine }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(query)
                    || $0.city.localizedCaseInsensitiveContains(query)
                    || $0.country.localizedCaseInsensitiveContains(query)
                    || $0.cuisine.displayName.localizedCaseInsensitiveContains(query)
            }
        }
        switch sort {
        case .recent:
            return list.sorted { $0.addedAt > $1.addedAt }
        case .alphabetical:
            return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .mostSpent:
            return list.sorted { $0.totalSpendHome > $1.totalSpendHome }
        case .michelinOnly:
            return list.sorted {
                $0.michelinStars == $1.michelinStars
                    ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    : $0.michelinStars > $1.michelinStars
            }
        }
    }

    private var hasActiveFilters: Bool {
        selectedCuisine != nil || sort == .michelinOnly
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if restaurants.isEmpty {
                        emptyCollection
                    } else {
                        searchRow
                        cuisineChips
                        if visiblePlates.isEmpty {
                            noMatches
                        } else {
                            grid
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color.plBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Restaurant.self) { restaurant in
                RestaurantDetailView(restaurant: restaurant)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("COLLECTION")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Color.plTextSecondary)
            Text(plateCountText)
                .font(.plDisplay(36))
                .foregroundStyle(Color.plText)
        }
        .padding(.top, 8)
    }

    // MARK: - Search & sort

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.plTextSecondary)
                TextField("Search plates", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.plText)
                    .tint(Color.plGold)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Haptics.tap()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.plTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.plSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.plStroke, lineWidth: 1)
            )

            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(CollectionSortOption.allCases) { option in
                        Label(option.rawValue, systemImage: option.symbol).tag(option)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(sort == .recent ? Color.plTextSecondary : Color.plGold)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.plSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(sort == .recent ? Color.plStroke : Color.plGold.opacity(0.5),
                                          lineWidth: 1)
                    )
            }
            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
        }
    }

    // MARK: - Cuisine chips

    private var cuisineChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", emoji: nil, isSelected: selectedCuisine == nil) {
                    selectedCuisine = nil
                }
                ForEach(cuisinesPresent, id: \.cuisine) { entry in
                    chip(title: entry.cuisine.displayName,
                         emoji: entry.cuisine.emoji,
                         isSelected: selectedCuisine == entry.cuisine) {
                        selectedCuisine = selectedCuisine == entry.cuisine ? nil : entry.cuisine
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func chip(title: String, emoji: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() }
        } label: {
            HStack(spacing: 5) {
                if let emoji {
                    Text(emoji).font(.system(size: 13))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.plGold : Color.plTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.plGold.opacity(0.14) : Color.plSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.plGold.opacity(0.6) : Color.plStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grid

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                  spacing: 12) {
            ForEach(visiblePlates) { restaurant in
                NavigationLink(value: restaurant) {
                    PlateCard(restaurant: restaurant)
                }
                .buttonStyle(PlateCardPressStyle())
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Empty states

    private var emptyCollection: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .strokeBorder(LinearGradient.plGold, lineWidth: 1.5)
                    .frame(width: 150, height: 150)
                Circle()
                    .strokeBorder(Color.plGold.opacity(0.25), lineWidth: 1)
                    .frame(width: 126, height: 126)
                Circle()
                    .fill(Color.plSurface)
                    .frame(width: 104, height: 104)
                Circle()
                    .strokeBorder(Color.plStroke, lineWidth: 1)
                    .frame(width: 104, height: 104)
                Image(systemName: "fork.knife")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(LinearGradient.plGold)
            }
            .shadow(color: Color.plGold.opacity(0.25), radius: 26)

            Text("No plates yet")
                .font(.plDisplay(26))
                .foregroundStyle(Color.plText)
                .padding(.top, 28)

            Text("Every receipt becomes a plate.")
                .font(.system(size: 15))
                .foregroundStyle(Color.plTextSecondary)
                .padding(.top, 6)

            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 13, weight: .medium))
                Text("Scan your first receipt to start collecting")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Color.plGold)
            .padding(.top, 18)
        }
        .frame(maxWidth: .infinity, minHeight: 440)
    }

    private var noMatches: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Color.plTextSecondary)
            Text("No matches")
                .font(.plDisplay(20))
                .foregroundStyle(Color.plText)
            Text("Try a different search or filter.")
                .font(.system(size: 14))
                .foregroundStyle(Color.plTextSecondary)
            if hasActiveFilters {
                Button {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        searchText = ""
                        selectedCuisine = nil
                        sort = .recent
                    }
                } label: {
                    Text("Clear filters")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.plGold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.plGold.opacity(0.14))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.plGold.opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}

// MARK: - Sort options

private enum CollectionSortOption: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case alphabetical = "A–Z"
    case mostSpent = "Most spent"
    case michelinOnly = "Michelin only"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .recent: return "clock"
        case .alphabetical: return "textformat.abc"
        case .mostSpent: return "banknote"
        case .michelinOnly: return "star.circle"
        }
    }
}

// MARK: - Press effect

private struct PlateCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
