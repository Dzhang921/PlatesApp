import PhotosUI
import SwiftUI
import UIKit
import VisionKit

/// VisionKit document camera wrapped for SwiftUI. Full-screen, edge-detecting,
/// multi-page — the "point at the receipt" moment.
struct ReceiptScannerView: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onScan(pages)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            onCancel()
        }
    }
}

/// The scanner step: camera full screen with a small "Enter manually" affordance
/// floating above the shutter area.
struct ScannerStepView: View {
    var model: CaptureModel
    var onClose: () -> Void

    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        ReceiptScannerView(
            onScan: { images in model.handleScan(images) },
            onCancel: { onClose() }
        )
        .ignoresSafeArea()
        // The document camera owns the bottom of the screen (flash, filters,
        // shutter); the strip below its top bar is the only safe free space.
        .overlay(alignment: .top) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 3, matching: .images) {
                    scannerPill("From Photos", symbol: "photo.on.rectangle")
                }
                Button {
                    Haptics.tap()
                    model.switchToManual()
                } label: {
                    scannerPill("Enter manually", symbol: "square.and.pencil")
                }
            }
            .padding(.top, 112)
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await scanPickedPhotos(items) }
            }
        }
        .statusBarHidden()
    }

    private func scannerPill(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.plText)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.plSurfaceElevated.opacity(0.92)))
            .overlay(Capsule().strokeBorder(Color.plStroke, lineWidth: 1))
    }

    /// Library photos go through the exact same OCR pipeline as a live scan.
    private func scanPickedPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        photoItems = []
        guard !images.isEmpty else { return }
        Haptics.tap()
        model.handleScan(images)
    }
}
