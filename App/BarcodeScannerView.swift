import AVFoundation
import SwiftUI
import Vision

struct BarcodeScannerView: UIViewControllerRepresentable {
    static var isScannerAvailable: Bool {
        BarcodeCaptureViewController.defaultVideoDevice() != nil
    }

    let scanFormatProfile: ScanFormatProfile
    let flashlightMode: ScannerFlashlightMode
    @Binding var isTorchAvailable: Bool
    @Binding var isTorchOn: Bool
    @Binding var statusMessage: String?
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCode: onCode,
            isTorchAvailable: $isTorchAvailable,
            isTorchOn: $isTorchOn,
            statusMessage: $statusMessage
        )
    }

    func makeUIViewController(context: Context) -> BarcodeCaptureViewController {
        let controller = BarcodeCaptureViewController()
        controller.delegate = context.coordinator
        controller.scanFormatProfile = scanFormatProfile
        controller.setTorch(on: flashlightMode == .on)
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeCaptureViewController, context: Context) {
        uiViewController.scanFormatProfile = scanFormatProfile
        uiViewController.setTorch(on: flashlightMode == .on)
    }

    static func dismantleUIViewController(_ uiViewController: BarcodeCaptureViewController, coordinator: Coordinator) {
        uiViewController.setTorch(on: false)
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, BarcodeCaptureViewControllerDelegate {
        private let onCode: (String) -> Void
        private var isTorchAvailable: Binding<Bool>
        private var isTorchOn: Binding<Bool>
        private var statusMessage: Binding<String?>

        init(
            onCode: @escaping (String) -> Void,
            isTorchAvailable: Binding<Bool>,
            isTorchOn: Binding<Bool>,
            statusMessage: Binding<String?>
        ) {
            self.onCode = onCode
            self.isTorchAvailable = isTorchAvailable
            self.isTorchOn = isTorchOn
            self.statusMessage = statusMessage
        }

        func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didScan code: String) {
            onCode(code)
        }

        func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateTorchAvailability isAvailable: Bool, isOn: Bool) {
            isTorchAvailable.wrappedValue = isAvailable
            isTorchOn.wrappedValue = isOn
        }

        func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateStatus message: String?) {
            statusMessage.wrappedValue = message
        }
    }
}

private extension ScanFormatProfile {
    var visionSymbologies: [VNBarcodeSymbology] {
        switch self {
        case .commonBarcodes:
            [
                .code39,
                .code128,
                .ean8,
                .ean13,
                .i2of5,
                .itf14,
                .upce,
            ]
        case .barcodesAndQR:
            [
                .code39,
                .code128,
                .ean8,
                .ean13,
                .i2of5,
                .itf14,
                .qr,
                .upce,
            ]
        case .allSupported:
            [
                .aztec,
                .code39,
                .code128,
                .dataMatrix,
                .ean8,
                .ean13,
                .i2of5,
                .itf14,
                .pdf417,
                .qr,
                .upce,
            ]
        }
    }
}

protocol BarcodeCaptureViewControllerDelegate: AnyObject {
    func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didScan code: String)
    func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateTorchAvailability isAvailable: Bool, isOn: Bool)
    func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateStatus message: String?)
}

final class BarcodeCaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: BarcodeCaptureViewControllerDelegate?
    var scanFormatProfile: ScanFormatProfile = .allSupported {
        didSet {
            guard oldValue != scanFormatProfile else { return }
            updateScanSymbologies()
        }
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.antoniobeslic.BarcodeKeyboard.camera")
    private let visionQueue = DispatchQueue(label: "com.antoniobeslic.BarcodeKeyboard.vision")
    private let videoOutput = AVCaptureVideoDataOutput()

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDevice: AVCaptureDevice?
    private var barcodeRequest: VNDetectBarcodesRequest?
    private var isConfigured = false
    private var isProcessingFrame = false
    private var didScan = false
    private var desiredTorchOn = false

    static func defaultVideoDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configurePreviewLayer()
        configureVision()
        requestCameraAccessAndConfigure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    func startScanning() {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            self.applyTorchState()
        }
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.setTorchOnSessionQueue(false)
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func setTorch(on isOn: Bool) {
        desiredTorchOn = isOn
        sessionQueue.async { [weak self] in
            self?.applyTorchState()
        }
    }

    private func configurePreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    private func configureVision() {
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            self?.handleBarcodeRequest(request, error: error)
        }
        barcodeRequest = request
        updateScanSymbologies()
    }

    private func updateScanSymbologies() {
        barcodeRequest?.symbologies = scanFormatProfile.visionSymbologies
    }

    private func requestCameraAccessAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            updateStatus(NSLocalizedString("Waiting for camera permission", comment: "Camera permission waiting status"))
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureSession()
                } else {
                    self.updateStatus(NSLocalizedString("Camera permission denied", comment: "Camera permission denied status"))
                }
            }
        case .denied, .restricted:
            updateStatus(NSLocalizedString("Camera permission denied", comment: "Camera permission denied status"))
        @unknown default:
            updateStatus(NSLocalizedString("Camera unavailable", comment: "Camera unavailable status"))
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }

            guard let device = Self.defaultVideoDevice() else {
                self.updateStatus(NSLocalizedString("Camera unavailable", comment: "Camera unavailable status"))
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)

                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                guard self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    self.updateStatus(NSLocalizedString("Camera input unavailable", comment: "Camera input unavailable status"))
                    return
                }
                self.session.addInput(input)

                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)

                guard self.session.canAddOutput(self.videoOutput) else {
                    self.session.commitConfiguration()
                    self.updateStatus(NSLocalizedString("Camera output unavailable", comment: "Camera output unavailable status"))
                    return
                }
                self.session.addOutput(self.videoOutput)

                if let connection = self.videoOutput.connection(with: .video),
                   connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }

                self.session.commitConfiguration()

                self.videoDevice = device
                self.isConfigured = true
                self.updateStatus(nil)
                self.publishTorchState()
                self.startScanning()
            } catch {
                self.updateStatus(NSLocalizedString("Camera failed to start", comment: "Camera failed to start status"))
            }
        }
    }

    private func applyTorchState() {
        setTorchOnSessionQueue(desiredTorchOn)
    }

    private func setTorchOnSessionQueue(_ isOn: Bool) {
        guard let device = videoDevice, device.hasTorch else {
            publishTorchState(isAvailable: false, isOn: false)
            return
        }

        do {
            try device.lockForConfiguration()
            if isOn, device.isTorchModeSupported(.on) {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            let currentTorchState = device.torchMode == .on
            device.unlockForConfiguration()
            publishTorchState(isAvailable: true, isOn: currentTorchState)
        } catch {
            publishTorchState(isAvailable: device.hasTorch, isOn: device.torchMode == .on)
        }
    }

    private func publishTorchState() {
        guard let device = videoDevice else {
            publishTorchState(isAvailable: false, isOn: false)
            return
        }

        publishTorchState(isAvailable: device.hasTorch, isOn: device.torchMode == .on)
    }

    private func publishTorchState(isAvailable: Bool, isOn: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.barcodeCaptureViewController(
                self,
                didUpdateTorchAvailability: isAvailable,
                isOn: isOn
            )
        }
    }

    private func updateStatus(_ message: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.barcodeCaptureViewController(self, didUpdateStatus: message)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !didScan, !isProcessingFrame, let barcodeRequest else { return }

        isProcessingFrame = true
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([barcodeRequest])
        } catch {
            isProcessingFrame = false
        }
    }

    private func handleBarcodeRequest(_ request: VNRequest, error: Error?) {
        defer { isProcessingFrame = false }

        guard error == nil, !didScan else { return }
        let observation = request.results?
            .compactMap { $0 as? VNBarcodeObservation }
            .first { observation in
                guard let value = observation.payloadStringValue else { return false }
                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

        guard let code = observation?.payloadStringValue else { return }
        didScan = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.barcodeCaptureViewController(self, didScan: code)
        }
    }
}
