import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Full page for one collected plate: photo hero, Michelin row, stat strip,
/// inline notes, and the visit history with receipts, line items, and food photos.
struct RestaurantDetailView: View {
    @Bindable var restaurant: Restaurant

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var shareImage: UIImage?
    @State private var showRenameAlert = false
    @State private var draftName = ""
    @State private var visitToDelete: Visit?
    @State private var showDeleteVisitDialog = false
    @State private var showDeleteRestaurantDialog = false

    private var homeCurrency: String { CurrencyConverter.homeCurrency }

    /// Food photos first (newest visit first), then receipt shots.
    private var heroPhotoPaths: [String] {
        let visits = restaurant.sortedVisits
        return visits.flatMap(\.foodPhotoPaths) + visits.compactMap(\.receiptImagePath)
    }

    private var averagePerVisit: Decimal {
        let count = restaurant.visitCount
        guard count > 0 else { return 0 }
        return restaurant.totalSpendHome / Decimal(count)
    }

    var body: some View {
        List {
            Group {
                heroSection
                titleSection
                statStrip
                notesSection
                visitsHeader
                if restaurant.sortedVisits.isEmpty {
                    emptyVisits
                } else {
                    ForEach(restaurant.sortedVisits) { visit in
                        CollectionVisitRow(visit: visit, homeCurrency: homeCurrency) {
                            visitToDelete = visit
                            showDeleteVisitDialog = true
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.plBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .confirmationDialog("Delete this visit?",
                            isPresented: $showDeleteVisitDialog,
                            titleVisibility: .visible) {
            Button("Delete Visit", role: .destructive) {
                if let visit = visitToDelete { delete(visit) }
            }
            Button("Cancel", role: .cancel) { visitToDelete = nil }
        } message: {
            Text("Its receipt and food photos are removed too.")
        }
        .alert("Rename Restaurant", isPresented: $showRenameAlert) {
            TextField("Restaurant name", text: $draftName)
            Button("Save") { commitRename() }
            Button("Cancel", role: .cancel) {}
        }
        .task { renderShareCard() }
        .onChange(of: restaurant.name) { renderShareCard() }
        .onChange(of: restaurant.cuisineRaw) { renderShareCard() }
        .onChange(of: restaurant.visitCount) { renderShareCard() }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroSection: some View {
        Group {
            if heroPhotoPaths.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.plSurfaceElevated)
                    VStack(spacing: 10) {
                        Text(restaurant.cuisine.emoji)
                            .font(.system(size: 88))
                        Text("No photos yet — add some below")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.plTextSecondary)
                    }
                }
                .frame(height: 250)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.plStroke, lineWidth: 1)
                )
            } else {
                TabView {
                    ForEach(heroPhotoPaths, id: \.self) { path in
                        CollectionHeroPhoto(path: path)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: heroPhotoPaths.count > 1 ? .automatic : .never))
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.plStroke, lineWidth: 1)
                )
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(restaurant.name)
                .font(.plDisplay(30))
                .foregroundStyle(Color.plText)
                .fixedSize(horizontal: false, vertical: true)

            if !restaurant.city.isEmpty || !restaurant.country.isEmpty {
                Text([restaurant.city, restaurant.country]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · "))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.plTextSecondary)
            }

            HStack(spacing: 8) {
                detailChip {
                    HStack(spacing: 5) {
                        Text(restaurant.cuisine.emoji).font(.system(size: 12))
                        Text(restaurant.cuisine.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.plTextSecondary)
                    }
                }
                if restaurant.isMichelin {
                    detailChip {
                        HStack(spacing: 4) {
                            HStack(spacing: 2) {
                                ForEach(0..<restaurant.michelinStars, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                            }
                            Text("Michelin")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.plMichelin)
                    }
                } else if restaurant.isBibGourmand {
                    detailChip {
                        Text("Bib Gourmand")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.plMichelin)
                    }
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
    }

    private func detailChip(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.plSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.plStroke, lineWidth: 1)
            )
    }

    // MARK: - Stats

    private var statStrip: some View {
        HStack(spacing: 0) {
            statColumn(label: "Visits", value: "\(restaurant.visitCount)", gold: false)
            statDivider
            statColumn(label: "Total", value: plMoney(restaurant.totalSpendHome, homeCurrency), gold: true)
            statDivider
            statColumn(label: "Avg / Visit", value: plMoney(averagePerVisit, homeCurrency), gold: true)
        }
        .plCard(padding: 14)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.plStroke)
            .frame(width: 1, height: 30)
    }

    private func statColumn(label: String, value: String, gold: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.plNumber(17))
                .foregroundStyle(gold ? Color.plGold : Color.plText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.plTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.plTextSecondary)
            TextField("The dish to order, the table to ask for…",
                      text: $restaurant.notes,
                      axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(Color.plText)
                .tint(Color.plGold)
                .lineLimit(2...6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard(padding: 14)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
    }

    // MARK: - Visits

    private var visitsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Visits")
                .font(.plDisplay(22))
                .foregroundStyle(Color.plText)
            Spacer()
            Text("\(restaurant.visitCount)")
                .font(.plNumber(15))
                .foregroundStyle(Color.plTextSecondary)
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 4, trailing: 20))
    }

    private var emptyVisits: some View {
        VStack(spacing: 8) {
            Image(systemName: "receipt")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Color.plTextSecondary)
            Text("No visits recorded")
                .font(.plDisplay(17))
                .foregroundStyle(Color.plText)
            Text("Scan the next receipt from here to log a return trip.")
                .font(.system(size: 13))
                .foregroundStyle(Color.plTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .plCard(padding: 24)
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 8, trailing: 20))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let shareImage {
                ShareLink(item: Image(uiImage: shareImage),
                          preview: SharePreview(restaurant.name, image: Image(uiImage: shareImage))) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.plGold)
                }
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
            }
            Menu {
                Button {
                    draftName = restaurant.name
                    showRenameAlert = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Picker(selection: $restaurant.cuisine) {
                    ForEach(Cuisine.allCases) { cuisine in
                        Text("\(cuisine.emoji)  \(cuisine.displayName)").tag(cuisine)
                    }
                } label: {
                    Label("Change Cuisine", systemImage: "fork.knife")
                }
                .pickerStyle(.menu)
                Divider()
                Button(role: .destructive) {
                    showDeleteRestaurantDialog = true
                } label: {
                    Label("Delete Restaurant", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Color.plGold)
            }
            .confirmationDialog("Delete \(restaurant.name)?",
                                isPresented: $showDeleteRestaurantDialog,
                                titleVisibility: .visible) {
                Button("Delete Restaurant", role: .destructive) { deleteRestaurant() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the plate, every visit, and all of its receipts and photos.")
            }
        }
    }

    // MARK: - Actions

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        restaurant.name = trimmed
        try? modelContext.save()
        Haptics.success()
    }

    private func delete(_ visit: Visit) {
        if let path = visit.receiptImagePath { ImageStore.delete(path) }
        for path in visit.foodPhotoPaths { ImageStore.delete(path) }
        modelContext.delete(visit)
        try? modelContext.save()
        visitToDelete = nil
        Haptics.success()
        refreshWidget()
    }

    private func deleteRestaurant() {
        for visit in restaurant.visits {
            if let path = visit.receiptImagePath { ImageStore.delete(path) }
            for path in visit.foodPhotoPaths { ImageStore.delete(path) }
        }
        modelContext.delete(restaurant)
        try? modelContext.save()
        Haptics.success()
        refreshWidget()
        dismiss()
    }

    private func refreshWidget() {
        let all = (try? modelContext.fetch(FetchDescriptor<Restaurant>())) ?? []
        WidgetSnapshotWriter.write(restaurants: all)
    }

    private func renderShareCard() {
        let renderer = ImageRenderer(content: RestaurantShareCard(restaurant: restaurant))
        renderer.scale = 2
        renderer.isOpaque = true
        shareImage = renderer.uiImage
    }
}

// MARK: - Visit row

private struct CollectionVisitRow: View {
    @Bindable var visit: Visit
    let homeCurrency: String
    var onDelete: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            receiptThumb
            VStack(alignment: .leading, spacing: 7) {
                Text(visit.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.plText)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(plMoney(visit.amount, visit.currencyCode))
                        .font(.plNumber(16))
                        .foregroundStyle(Color.plGold)
                    if visit.currencyCode != homeCurrency {
                        Text("≈ \(plMoney(visit.amountHome, homeCurrency))")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.plTextSecondary)
                    }
                }

                if !visit.lineItems.isEmpty {
                    lineItemsDisclosure
                }

                if !visit.foodPhotoPaths.isEmpty {
                    foodPhotoStrip
                }

                PhotosPicker(selection: $pickerItems,
                             maxSelectionCount: 6,
                             matching: .images) {
                    Label("Add food photos", systemImage: "photo.badge.plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.plGold)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .plCard(padding: 14)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            attach(items)
        }
    }

    @ViewBuilder
    private var receiptThumb: some View {
        if let path = visit.receiptImagePath {
            CollectionThumb(path: path, width: 54, height: 70, corner: 10)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.plSurfaceElevated)
                .frame(width: 54, height: 70)
                .overlay(
                    Image(systemName: "receipt")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Color.plTextSecondary)
                )
        }
    }

    private var lineItemsDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(visit.lineItems) { item in
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.plText)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let price = item.price {
                            Text(plMoney(price, visit.currencyCode))
                                .font(.plNumber(13, weight: .semibold))
                                .foregroundStyle(Color.plTextSecondary)
                        }
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            Text("\(visit.lineItems.count) line item\(visit.lineItems.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.plTextSecondary)
        }
        .tint(Color.plTextSecondary)
    }

    private var foodPhotoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(visit.foodPhotoPaths, id: \.self) { path in
                    CollectionThumb(path: path, width: 44, height: 44, corner: 8)
                }
            }
        }
    }

    private func attach(_ items: [PhotosPickerItem]) {
        Task {
            var added = false
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let name = ImageStore.save(image) {
                    visit.foodPhotoPaths.append(name)
                    added = true
                }
            }
            pickerItems = []
            if added { Haptics.success() }
        }
    }
}

// MARK: - Image helpers

private struct CollectionThumb: View {
    let path: String
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(Color.plSurfaceElevated)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.plStroke, lineWidth: 1)
        )
        .task(id: path) {
            image = ImageStore.load(path)
        }
    }
}

private struct CollectionHeroPhoto: View {
    let path: String

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color.plSurfaceElevated)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: path) {
            image = ImageStore.load(path)
        }
    }
}
