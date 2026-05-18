import SwiftUI
import AVFoundation
import UIKit
import SuiWidgetKit

/// SwiftUI wrapper around AVCaptureSession for QR-code scanning.
/// Presented as a sheet; calls `onScan(payload)` once on first successful decode,
/// then the parent dismisses the sheet.
public struct QRScannerView: View {
    public let onScan: (String) -> Void
    public let onCancel: () -> Void
    @State private var permissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var scannerError: String?

    public init(onScan: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onScan = onScan
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            content
                .navigationTitle("Scan QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { onCancel() }
                    }
                }
        }
        .onAppear { checkPermission() }
    }

    @ViewBuilder
    private var content: some View {
        switch permissionStatus {
        case .authorized:
            CameraPreview(onScan: onScan, onError: { scannerError = $0 })
                .overlay(scannerOverlay)
                .overlay(alignment: .bottom) {
                    if let scannerError {
                        Text(scannerError)
                            .font(SuiTypography.body(12, weight: .semibold))
                            .padding()
                            .background(SuiColor.coral.opacity(0.9), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(.bottom, SuiSpacing.s5)
                    }
                }
        case .notDetermined:
            ProgressView("Requesting camera access…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied, .restricted:
            VStack(spacing: SuiSpacing.s3) {
                Spacer()
                Image(systemName: "camera.fill").font(.system(size: 48)).foregroundStyle(.secondary)
                Text("Camera access required").font(SuiTypography.display(20))
                Text("Sui Widget needs camera access to scan QR codes. Open Settings → Sui Widget → Camera to enable.")
                    .font(SuiTypography.body(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(SuiTypography.body(15, weight: .semibold))
                .padding(.horizontal, SuiSpacing.s4)
                .padding(.vertical, SuiSpacing.s2)
                .background(SuiColor.suiBlue, in: Capsule())
                .foregroundStyle(.white)
                Spacer()
            }
        @unknown default:
            ProgressView()
        }
    }

    private var scannerOverlay: some View {
        ZStack {
            // Cutout viewport guide
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white, lineWidth: 3)
                .frame(width: 260, height: 260)
            VStack {
                Spacer()
                Text("Point the camera at a QR code")
                    .font(SuiTypography.body(12, weight: .semibold))
                    .padding(SuiSpacing.s2)
                    .background(.black.opacity(0.6), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, SuiSpacing.s5 * 2)
            }
        }
    }

    private func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = status
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    permissionStatus = granted ? .authorized : .denied
                }
            }
        }
    }
}

/// UIViewControllerRepresentable that owns the AVCaptureSession.
private struct CameraPreview: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = onScan
        vc.onError = onError
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

/// Owns the AVCaptureSession lifecycle.
private final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(for: .video) else {
            onError?("No camera available on this device")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                onError?("Cannot read from camera")
                return
            }
        } catch {
            onError?("Camera setup failed: \(error.localizedDescription)")
            return
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.metadataObjectTypes = [.qr]
            output.setMetadataObjectsDelegate(self, queue: .main)
        } else {
            onError?("Cannot configure QR output")
            return
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer

        session.commitConfiguration()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didScan else { return }
        guard let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadata.type == .qr,
              let payload = metadata.stringValue,
              !payload.isEmpty else { return }
        didScan = true
        // Lightweight haptic feedback.
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.async { [weak self] in
            self?.session.stopRunning()
            self?.onScan?(payload)
        }
    }
}
