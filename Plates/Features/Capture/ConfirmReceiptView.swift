import SwiftData
import SwiftUI
import UIKit

/// The confirm screen — every parsed field is editable, the place gets picked
/// here, and Michelin / duplicate / cuisine intelligence lights up as you go.
struct ConfirmReceiptView: View {
    @Bindable var model: CaptureModel
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store
    @Query private var restaurants: [Restaurant]

    @State private var showReceiptViewer = false
    @State private var itemsExpanded = false
    @State private var cuisineFilter = ""
    @FocusState private var totalFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            CaptureHeader(title: "Confirm your plate", onClose: onClose)

            List {
                receiptSection
                if !model.lineItems.isEmpty { lineItemsSection }
                placeSection
                cuisineSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(14)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.defaultMinListRowHeight, 44)
        }
        .background(Color.plBackground)
        .safeAreaInset(edge: .bottom) { saveArea }
        .fullScreenCover(isPresented: $showReceiptViewer) {
            if let image = model.receiptImages.first {
                ReceiptImageViewer(image: image)
            }
        }
        .sheet(isPresented: $model.showPaywall, onDismiss: {
            if store.canAddRestaurant(currentCount: restaurants.count) {
                model.attemptSave(context: modelContext, store: store, restaurants: restaurants)
            }
        }) {
            PaywallView()
        }
        .onAppear {
            model.existingRestaurants = restaurants
            itemsExpanded = model.lineItems.count <= 4
        }
        .onChange(of: restaurants.count) {
            model.existingRestaurants = restaurants
        }
    }

    // MARK: - Receipt fields

    private var receiptSection: some View {
        Section {
            HStack(alignment: .top, spacing: 14) {
                receiptThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text("Merchant")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.plTextSecondary)
                        .textCase(.uppercase)
                        .kerning(1.1)
                    TextField("Restaurant name", text: $model.merchantName)
                        .font(.plDisplay(21, weight: .medium))
                        .foregroundStyle(Color.plText)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.plSurface)

            HStack {
                Label {
                    Text("Date").foregroundStyle(Color.plText)
                } icon: {
                    Image(systemName: "calendar").foregroundStyle(Color.plGold)
                }
                Spacer()
                DatePicker("", selection: $model.visitDate,
                           in: ...Date.now,
                           displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(Color.plGold)
            }
            .listRowBackground(Color.plSurface)

            HStack(spacing: 12) {
                Label {
                    Text("Total").foregroundStyle(Color.plText)
                } icon: {
                    Image(systemName: "banknote").foregroundStyle(Color.plGold)
                }
                Spacer()
                TextField("0.00", text: $model.totalText)
                    .font(.plNumber(19))
                    .foregroundStyle(Color.plGold)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($totalFocused)
                    .frame(maxWidth: 120)
                CurrencyMenu(code: $model.currencyCode)
            }
            .listRowBackground(Color.plSurface)
        }
        .listRowSeparatorTint(Color.plStroke)
    }

    @ViewBuilder
    private var receiptThumbnail: some View {
        if let image = model.receiptImages.first {
            Button {
                Haptics.tap()
                showReceiptViewer = true
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.plStroke, lineWidth: 1))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.plText)
                            .padding(4)
                            .background(Circle().fill(Color.plBackground.opacity(0.75)))
                            .padding(3)
                    }
            }
            .buttonStyle(.plain)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.plSurfaceElevated)
                .frame(width: 58, height: 76)
                .overlay {
                    Image(systemName: "receipt")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.plTextSecondary)
                }
        }
    }

    // MARK: - Line items

    private var lineItemsSection: some View {
        Section {
            if model.lineItems.count > 4 {
                Button {
                    Haptics.tap()
                    withAnimation(.snappy) { itemsExpanded.toggle() }
                } label: {
                    HStack {
                        Label {
                            Text("\(model.lineItems.count) items")
                                .foregroundStyle(Color.plText)
                        } icon: {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundStyle(Color.plGold)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.plTextSecondary)
                            .rotationEffect(.degrees(itemsExpanded ? 180 : 0))
                    }
                }
                .listRowBackground(Color.plSurface)
            }
            if itemsExpanded || model.lineItems.count <= 4 {
                ForEach(model.lineItems) { item in
                    HStack {
                        Text(item.name)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.plText)
                            .lineLimit(1)
                        Spacer()
                        if let price = item.price {
                            Text(plMoney(price, model.currencyCode))
                                .font(.plNumber(15, weight: .medium))
                                .foregroundStyle(Color.plTextSecondary)
                        }
                    }
                    .listRowBackground(Color.plSurface)
                }
                .onDelete { offsets in
                    model.removeLineItems(at: offsets)
                }
            }
        } header: {
            if model.lineItems.count <= 4 {
                Text("On the receipt")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.plTextSecondary)
            }
        } footer: {
            if itemsExpanded || model.lineItems.count <= 4 {
                Text("Swipe left to remove anything that isn't a dish.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.plTextSecondary)
            }
        }
        .listRowSeparatorTint(Color.plStroke)
    }

    // MARK: - Place matching

    private var placeSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.plTextSecondary)
                TextField("Search for the restaurant", text: $model.placeQuery)
                    .foregroundStyle(Color.plText)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await model.searchPlaces() }
                    }
                if model.isSearchingPlaces {
                    ProgressView().tint(Color.plGold)
                }
            }
            .listRowBackground(Color.plSurfaceElevated)

            if model.candidates.isEmpty && !model.isSearchingPlaces {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.plTextSecondary)
                    Text("No places found yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.plText)
                    Text("Try the restaurant's name, or add a city to the search.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.plTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .listRowBackground(Color.plSurface)
            }

            ForEach(model.candidates.prefix(6)) { candidate in
                candidateRow(candidate)
            }

            if model.selectedPlace != nil, model.michelin != nil || model.duplicateOf != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if let record = model.michelin {
                        michelinChip(record)
                    }
                    if let existing = model.duplicateOf {
                        duplicateBanner(existing)
                    }
                }
                .listRowBackground(Color.plSurface)
            }
        } header: {
            Text("Where is it?")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.plTextSecondary)
        } footer: {
            Text("Pick the restaurant so it can light up on your globe.")
                .font(.system(size: 12))
                .foregroundStyle(model.selectedPlace == nil ? Color.plGold : Color.plTextSecondary)
        }
        .listRowSeparatorTint(Color.plStroke)
    }

    private func candidateRow(_ candidate: PlaceMatch) -> some View {
        let isSelected = model.selectedPlace?.id == candidate.id
        return Button {
            model.select(candidate)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "mappin.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.plGold : Color.plTextSecondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.name)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.plGold : Color.plText)
                        .lineLimit(1)
                    Text(candidate.address.isEmpty
                         ? [candidate.city, candidate.country].filter { !$0.isEmpty }.joined(separator: ", ")
                         : candidate.address)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.plTextSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if let meters = candidate.distanceMeters {
                    Text(Self.distanceLabel(meters))
                        .font(.plNumber(12, weight: .medium))
                        .foregroundStyle(Color.plTextSecondary)
                }
            }
            .padding(.vertical, 2)
        }
        .listRowBackground(isSelected ? Color.plGold.opacity(0.10) : Color.plSurface)
    }

    private func michelinChip(_ record: MichelinRecord) -> some View {
        HStack(spacing: 6) {
            if record.stars > 0 {
                ForEach(0..<record.stars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                }
                Text("Michelin")
                    .font(.system(size: 13, weight: .semibold))
            } else {
                Image(systemName: "rosette")
                    .font(.system(size: 13))
                Text("Bib Gourmand")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .foregroundStyle(Color.plMichelin)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.plMichelin.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.plMichelin.opacity(0.4), lineWidth: 1))
    }

    private func duplicateBanner(_ existing: Restaurant) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.plGold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Visit #\(model.visitNumber) at \(existing.name)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.plText)
                Text("Already on your globe — this saves as a repeat visit.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.plTextSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.plGold.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.plGold.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Cuisine

    /// Selected cuisine pinned first; typing narrows the chips so nothing is
    /// ever a long scroll away. An unmatched filter falls back to all.
    private var filteredCuisines: [Cuisine] {
        let filter = cuisineFilter.trimmingCharacters(in: .whitespaces)
        var pool = Cuisine.allCases
        if !filter.isEmpty {
            let narrowed = pool.filter { $0.displayName.localizedCaseInsensitiveContains(filter) }
            if !narrowed.isEmpty { pool = narrowed }
        }
        if let index = pool.firstIndex(of: model.cuisine), index > 0 {
            pool.remove(at: index)
            pool.insert(model.cuisine, at: 0)
        }
        return pool
    }

    private var cuisineSection: some View {
        Section {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.plTextSecondary)
                    TextField("Filter cuisines", text: $cuisineFilter)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.plText)
                        .autocorrectionDisabled()
                    if !cuisineFilter.isEmpty {
                        Button {
                            cuisineFilter = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.plTextSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.plSurfaceElevated))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(36), spacing: 8), GridItem(.fixed(36))],
                              spacing: 8) {
                        ForEach(filteredCuisines) { cuisine in
                            cuisineChip(cuisine)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .frame(height: 100)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.plSurface)
        } header: {
            Text("Cuisine")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.plTextSecondary)
        }
    }

    private func cuisineChip(_ cuisine: Cuisine) -> some View {
        let isSelected = model.cuisine == cuisine
        return Button {
            model.pickCuisine(cuisine)
        } label: {
            HStack(spacing: 6) {
                Text(cuisine.emoji)
                    .font(.system(size: 15))
                Text(cuisine.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.plBackground : Color.plText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient.plGold)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.plSurfaceElevated)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.clear : Color.plStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private var saveArea: some View {
        VStack(spacing: 10) {
            if model.selectedPlace == nil {
                Text("Pick the restaurant so it can light up on your globe")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.plTextSecondary)
            }
            Button {
                Haptics.tap()
                totalFocused = false
                model.attemptSave(context: modelContext, store: store, restaurants: restaurants)
            } label: {
                Text(model.duplicateOf == nil
                     ? "Collect this plate"
                     : "Log visit #\(model.visitNumber)")
            }
            .buttonStyle(PlPrimaryButtonStyle())
            .disabled(!model.canSave)
            .opacity(model.canSave ? 1 : 0.4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(Color.plBackground.opacity(0.94))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private static func distanceLabel(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        let km = meters / 1000
        return km < 10
            ? String(format: "%.1f km", km)
            : "\(Int(km.rounded())) km"
    }
}

// MARK: - Full-screen receipt viewer

/// Tap the thumbnail → the receipt fills the screen, pinch to inspect the fine print.
struct ReceiptImageViewer: View {
    var image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoom * pinch)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(
                    MagnificationGesture()
                        .updating($pinch) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            zoom = min(max(zoom * value, 1), 5)
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.snappy) { zoom = zoom > 1 ? 1 : 2.5 }
                }

            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.plText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.plSurfaceElevated.opacity(0.9)))
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }
}
