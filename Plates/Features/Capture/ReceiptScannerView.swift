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

    var body: some View {
        ZStack(alignment: .bottom) {
            ReceiptScannerView(
                onScan: { images in model.handleScan(images) },
                onCancel: { onClose() }
            )
            .ignoresSafeArea()

            Button {
                Haptics.tap()
                model.switchToManual()
            } label: {
                Label("Enter manually", systemImage: "square.and.pencil")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.plText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.plSurfaceElevated.opacity(0.92)))
                    .overlay(Capsule().strokeBorder(Color.plStroke, lineWidth: 1))
            }
            .padding(.bottom, 118)
        }
        .statusBarHidden()
    }
}
