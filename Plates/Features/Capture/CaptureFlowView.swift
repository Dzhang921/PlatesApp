import PhotosUI
import SwiftUI
import UIKit

/// The capture flow, presented as a fullScreenCover: scan → parse → confirm → celebrate.
struct CaptureFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = CaptureModel()

    var body: some View {
        ZStack {
            Color.plBackground.ignoresSafeArea()

            switch model.step {
            case .scanner:
                ScannerStepView(model: model, onClose: { dismiss() })
                    .transition(.opacity)
            case .manual:
                ManualEntryView(model: model, onClose: { dismiss() })
                    .transition(.opacity)
            case .parsing:
                ParsingOverlayView(image: model.receiptImages.first)
                    .transition(.opacity)
            case .confirm:
                ConfirmReceiptView(model: model, onClose: { dismiss() })
                    .transition(.opacity)
            case .celebration:
                CelebrationView(model: model, onDone: { dismiss() })
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { LocationProvider.shared.request() }
    }
}

// MARK: - Manual entry

/// Clean fallback form — the only path on Simulator, and the rescue path for
/// unscannable receipts.
struct ManualEntryView: View {
    @Bindable var model: CaptureModel
    var onClose: () -> Void

    @State private var photoItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?

    private enum Field { case name, total }

    var body: some View {
        VStack(spacing: 0) {
            CaptureHeader(title: "New plate", onClose: onClose)

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Restaurant")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.plTextSecondary)
                            .textCase(.uppercase)
                            .kerning(1.2)
                        HStack(spacing: 10) {
                            Image(systemName: "fork.knife")
                                .foregroundStyle(Color.plGold)
                            TextField("Where did you eat?", text: $model.merchantName)
                                .font(.plDisplay(20, weight: .medium))
                                .foregroundStyle(Color.plText)
                                .focused($focusedField, equals: .name)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .total }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.plSurfaceElevated))
                    }
                    .plCard()

                    VStack(spacing: 0) {
                        HStack {
                            Label("Date", systemImage: "calendar")
                                .foregroundStyle(Color.plText)
                            Spacer()
                            DatePicker("", selection: $model.visitDate,
                                       in: ...Date.now,
                                       displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(Color.plGold)
                        }
                        .padding(.vertical, 12)

                        Divider().overlay(Color.plStroke)

                        HStack(spacing: 12) {
                            Label("Total", systemImage: "banknote")
                                .foregroundStyle(Color.plText)
                            Spacer()
                            TextField("0.00", text: $model.totalText)
                                .font(.plNumber(20))
                                .foregroundStyle(Color.plGold)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .total)
                                .frame(maxWidth: 130)
                            CurrencyMenu(code: $model.currencyCode)
                        }
                        .padding(.vertical, 12)
                    }
                    .plCard()

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack(spacing: 12) {
                            if let image = model.receiptImages.first {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 52, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.plGold.opacity(0.6), lineWidth: 1))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Receipt attached")
                                        .foregroundStyle(Color.plText)
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Tap to replace")
                                        .foregroundStyle(Color.plTextSecondary)
                                        .font(.system(size: 13))
                                }
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.plGold)
                                    .frame(width: 52, height: 52)
                                    .background(Circle().fill(Color.plSurfaceElevated))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Add a receipt photo")
                                        .foregroundStyle(Color.plText)
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Optional — proof of the plate")
                                        .foregroundStyle(Color.plTextSecondary)
                                        .font(.system(size: 13))
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.plTextSecondary)
                        }
                        .plCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Haptics.tap()
                model.finishManualEntry()
            } label: {
                Text("Continue")
            }
            .buttonStyle(PlPrimaryButtonStyle())
            .disabled(model.merchantName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(model.merchantName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(Color.plBackground)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    model.receiptImages = [image]
                }
            }
        }
    }
}

// MARK: - Parsing overlay

/// Dark overlay with a gold shimmer ring while OCR runs.
struct ParsingOverlayView: View {
    var image: UIImage?
    @State private var spinning = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 22)
                    .opacity(0.22)
            }
            Color.plBackground.opacity(0.86).ignoresSafeArea()

            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .stroke(Color.plStroke, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(colors: [Color.plGoldDeep.opacity(0),
                                                     Color.plGoldDeep,
                                                     Color.plGold],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(spinning ? 360 : 0))
                        .animation(.linear(duration: 1.3).repeatForever(autoreverses: false),
                                   value: spinning)
                        .plGlow(.plGold, radius: 10)
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(LinearGradient.plGold)
                }
                .frame(width: 96, height: 96)

                VStack(spacing: 8) {
                    Text("Reading your receipt…")
                        .font(.plDisplay(22))
                        .foregroundStyle(Color.plText)
                    Text("Finding the merchant, date and total")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.plTextSecondary)
                }
            }
        }
        .onAppear { spinning = true }
    }
}

// MARK: - Shared bits

/// Flow header: X to leave at any step, centered title.
struct CaptureHeader: View {
    var title: String
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.plDisplay(19))
                .foregroundStyle(Color.plText)
            HStack {
                Button {
                    Haptics.tap()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.plTextSecondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.plSurfaceElevated))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

/// Compact currency selector fed by the rates file.
struct CurrencyMenu: View {
    @Binding var code: String

    var body: some View {
        Menu {
            ForEach(CurrencyConverter.supportedCurrencies, id: \.self) { currency in
                Button {
                    code = currency
                } label: {
                    if currency == code {
                        Label("\(CurrencyConverter.symbol(for: currency))  \(currency)",
                              systemImage: "checkmark")
                    } else {
                        Text("\(CurrencyConverter.symbol(for: currency))  \(currency)")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(code)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.plGold)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.plSurfaceElevated))
        }
    }
}
