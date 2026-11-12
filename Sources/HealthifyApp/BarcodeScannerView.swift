import SwiftUI
import AVFoundation

// MARK: - Barcode scanner. Camera asked for here, in context, with a reason.
// NOTE: the app target's Info.plist must declare NSCameraUsageDescription —
// see README "xtool packaging notes". Without it, iOS kills the scan.

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onCode = { code in
            onCode(code)
            dismiss()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController,
                                context: Context) {}
}

final class ScannerViewController: UIViewController,
    AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var fired = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async { self?.start() }
            }
        default:
            showDenied()
        }
    }

    private func start() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .ean8, .upce, .code128, .qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        session.startRunning()
    }

    private func showDenied() {
        let label = UILabel()
        label.text = "Camera access is off. Enter the barcode by hand — "
            + "nothing leaves this phone either way."
        label.textColor = .white
        label.numberOfLines = 0
        label.frame = view.bounds.insetBy(dx: 24, dy: 200)
        view.addSubview(label)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !fired,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        fired = true
        session.stopRunning()
        onCode?(code)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }
}
