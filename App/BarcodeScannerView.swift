import AVFoundation
import SwiftUI
import Vision

struct ScannerCodeResult: Equatable {
    let value: String
    let codeFormat: String?
    let isManualEntry: Bool
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    static var isScannerAvailable: Bool {
        BarcodeCaptureViewController.defaultVideoDevice() != nil
    }

    let scanFormatProfile: ScanFormatProfile
    let flashlightMode: ScannerFlashlightMode
    let defaultZoomFactor: Double
    let scanArea: ScannerScanArea
    @Binding var isTorchAvailable: Bool
    @Binding var isTorchOn: Bool
    @Binding var statusMessage: String?
    @Binding var currentZoomFactor: Double
    let onCode: (ScannerCodeResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCode: onCode,
            isTorchAvailable: $isTorchAvailable,
            isTorchOn: $isTorchOn,
            statusMessage: $statusMessage,
            currentZoomFactor: $currentZoomFactor
        )
    }

    func makeUIViewController(context: Context) -> BarcodeCaptureViewController {
        let controller = BarcodeCaptureViewController()
        controller.delegate = context.coordinator
        controller.scanFormatProfile = scanFormatProfile
        controller.defaultZoomFactor = defaultZoomFactor
        controller.scanArea = scanArea
        controller.setTorch(on: flashlightMode == .on)
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeCaptureViewController, context: Context) {
        uiViewController.scanFormatProfile = scanFormatProfile
        uiViewController.defaultZoomFactor = defaultZoomFactor
        uiViewController.scanArea = scanArea
        uiViewController.setTorch(on: flashlightMode == .on)
    }

    static func dismantleUIViewController(_ uiViewController: BarcodeCaptureViewController, coordinator: Coordinator) {
        uiViewController.setTorch(on: false)
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, BarcodeCaptureViewControllerDelegate {
        private let onCode: (ScannerCodeResult) -> Void
        private var isTorchAvailable: Binding<Bool>
        private var isTorchOn: Binding<Bool>
        private var statusMessage: Binding<String?>
        private var currentZoomFactor: Binding<Double>

        init(
            onCode: @escaping (ScannerCodeResult) -> Void,
            isTorchAvailable: Binding<Bool>,
            isTorchOn: Binding<Bool>,
            statusMessage: Binding<String?>,
            currentZoomFactor: Binding<Double>
        ) {
            self.onCode = onCode
            self.isTorchAvailable = isTorchAvailable
            self.isTorchOn = isTorchOn
            self.statusMessage = statusMessage
            self.currentZoomFactor = currentZoomFactor
        }

        func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didScan result: ScannerCodeResult) {
            onCode(result)
        }

        func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateTorchAvailability isAvailable: Bool, isOn: Bool) {
            isTorchAvailable.wrappedValue = isAvailable
            isTorchOn.wrappedValue = isOn
        }

        func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateZoomFactor zoomFactor: Double) {
            currentZoomFactor.wrappedValue = zoomFactor
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
    func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didScan result: ScannerCodeResult)
    func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateTorchAvailability isAvailable: Bool, isOn: Bool)
    func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateZoomFactor zoomFactor: Double)
    func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateStatus message: String?)
}

final class BarcodeCaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    private static let fullVisionRegion = CGRect(x: 0, y: 0, width: 1, height: 1)

    weak var delegate: BarcodeCaptureViewControllerDelegate?
    var scanFormatProfile: ScanFormatProfile = .allSupported {
        didSet {
            guard oldValue != scanFormatProfile else { return }
            updateScanSymbologies()
        }
    }
    var defaultZoomFactor: Double = 1.0 {
        didSet {
            guard oldValue != defaultZoomFactor else { return }
            applyZoomFactor(defaultZoomFactor)
        }
    }
    var scanArea: ScannerScanArea = .fullFrame {
        didSet {
            guard oldValue != scanArea else { return }
            updateScanAreaRegion()
        }
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.antoniobeslic.Blip.camera")
    private let visionQueue = DispatchQueue(label: "com.antoniobeslic.Blip.vision")
    private let videoOutput = AVCaptureVideoDataOutput()

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDevice: AVCaptureDevice?
    private var barcodeRequest: VNDetectBarcodesRequest?
    private var isConfigured = false
    private var isProcessingFrame = false
    private var didScan = false
    private var desiredTorchOn = false
    private var currentZoomFactor: Double = 1.0
    private var pinchStartZoomFactor: Double = 1.0
    private let scanAreaLock = NSLock()
    private var activeLayerScanRect: CGRect?
    private var activePreviewBounds: CGRect = .zero
    private var latestOrientedFrameSize: CGSize = .zero
    private var latestVisionRegionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)

    static func defaultVideoDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configurePreviewLayer()
        configurePinchGesture()
        configureVision()
        requestCameraAccessAndConfigure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateScanAreaRegion()
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

    func applyZoomFactor(_ requestedZoomFactor: Double) {
        sessionQueue.async { [weak self] in
            self?.setZoomFactorOnSessionQueue(requestedZoomFactor)
        }
    }

    private func configurePreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    private func configurePinchGesture() {
        let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        view.addGestureRecognizer(recognizer)
    }

    @objc private func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pinchStartZoomFactor = currentZoomFactor
        case .changed:
            applyZoomFactor(pinchStartZoomFactor * recognizer.scale)
        default:
            break
        }
    }

    private func configureVision() {
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            self?.handleBarcodeRequest(request, error: error)
        }
        request.revision = VNDetectBarcodesRequestRevision3
        barcodeRequest = request
        updateScanSymbologies()
        updateScanAreaRegion()
    }

    private func updateScanSymbologies() {
        barcodeRequest?.symbologies = scanFormatProfile.visionSymbologies
    }

    private func updateScanAreaRegion() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let layerScanRect: CGRect?
            let previewBounds = self.previewLayer?.bounds ?? .zero
            if self.scanArea == .centeredBox, let previewLayer = self.previewLayer {
                layerScanRect = ScannerScanAreaGuide.rect(in: previewLayer.bounds)
            } else {
                layerScanRect = nil
            }

            self.scanAreaLock.lock()
            self.activeLayerScanRect = layerScanRect
            self.activePreviewBounds = previewBounds
            self.scanAreaLock.unlock()

            self.visionQueue.async { [weak self] in
                self?.barcodeRequest?.regionOfInterest = Self.fullVisionRegion
            }
        }
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
                self.setZoomFactorOnSessionQueue(self.defaultZoomFactor)
                self.startScanning()
            } catch {
                self.updateStatus(NSLocalizedString("Camera failed to start", comment: "Camera failed to start status"))
            }
        }
    }

    private func setZoomFactorOnSessionQueue(_ requestedZoomFactor: Double) {
        guard let device = videoDevice else {
            publishZoomFactor(currentZoomFactor)
            return
        }

        let maxZoomFactor = max(1.0, Double(device.activeFormat.videoMaxZoomFactor))
        let clampedZoomFactor = min(max(requestedZoomFactor, 1.0), maxZoomFactor)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = CGFloat(clampedZoomFactor)
            device.unlockForConfiguration()
            currentZoomFactor = clampedZoomFactor
            publishZoomFactor(clampedZoomFactor)
        } catch {
            publishZoomFactor(currentZoomFactor)
        }
    }

    private func publishZoomFactor(_ zoomFactor: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.barcodeCaptureViewController(self, didUpdateZoomFactor: zoomFactor)
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
        let previewBounds = currentActivePreviewBounds()
        latestOrientedFrameSize = Self.orientedImageSize(
            for: sampleBuffer,
            previewBounds: previewBounds
        )
        latestVisionRegionOfInterest = currentActiveLayerScanRect().flatMap { layerScanRect in
            Self.visionRegionOfInterest(
                fromLayerRect: layerScanRect,
                orientedImageSize: latestOrientedFrameSize,
                previewBounds: previewBounds
            )
        } ?? Self.fullVisionRegion
        barcodeRequest.regionOfInterest = latestVisionRegionOfInterest

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
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                return self.isObservationInsideActiveScanArea(
                    observation,
                    orientedImageSize: self.latestOrientedFrameSize,
                    regionOfInterest: self.latestVisionRegionOfInterest
                )
            }

        guard let code = observation?.payloadStringValue else { return }
        didScan = true
        let result = ScannerCodeResult(
            value: code,
            codeFormat: observation?.symbology.rawValue,
            isManualEntry: false
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.barcodeCaptureViewController(self, didScan: result)
        }
    }

    private func isObservationInsideActiveScanArea(
        _ observation: VNBarcodeObservation,
        orientedImageSize: CGSize,
        regionOfInterest: CGRect
    ) -> Bool {
        guard let activeLayerScanRect = currentActiveLayerScanRect(),
              orientedImageSize.width > 0,
              orientedImageSize.height > 0 else {
            return true
        }

        let fullImageBoundingBox = Self.fullImageBoundingBox(
            fromRegionRelativeBoundingBox: observation.boundingBox,
            regionOfInterest: regionOfInterest
        )
        let observationLayerRect = Self.layerRect(
            fromVisionBoundingBox: fullImageBoundingBox,
            orientedImageSize: orientedImageSize,
            previewBounds: currentActivePreviewBounds()
        )
        let observationCenter = CGPoint(
            x: observationLayerRect.midX,
            y: observationLayerRect.midY
        )

        guard activeLayerScanRect.contains(observationCenter) else { return false }

        let overlap = activeLayerScanRect.intersection(observationLayerRect)
        guard !overlap.isNull, !overlap.isEmpty else { return false }

        let observationArea = max(observationLayerRect.width * observationLayerRect.height, 0.0001)
        let overlapArea = overlap.width * overlap.height
        return overlapArea / observationArea >= 0.65
    }

    private func currentActiveLayerScanRect() -> CGRect? {
        scanAreaLock.lock()
        defer { scanAreaLock.unlock() }
        return activeLayerScanRect
    }

    private func currentActivePreviewBounds() -> CGRect {
        scanAreaLock.lock()
        defer { scanAreaLock.unlock() }
        return activePreviewBounds
    }

    private static func orientedImageSize(for sampleBuffer: CMSampleBuffer, previewBounds: CGRect) -> CGSize {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return .zero
        }

        let rawSize = CGSize(
            width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)),
            height: CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        )
        let rotatedSize = CGSize(width: rawSize.height, height: rawSize.width)

        guard previewBounds.width > 0, previewBounds.height > 0, rawSize.height > 0 else {
            return rotatedSize
        }

        let previewAspectRatio = previewBounds.width / previewBounds.height
        let rawDelta = abs(rawSize.width / rawSize.height - previewAspectRatio)
        let rotatedDelta = abs(rotatedSize.width / rotatedSize.height - previewAspectRatio)

        return rawDelta <= rotatedDelta ? rawSize : rotatedSize
    }

    private static func layerRect(
        fromVisionBoundingBox boundingBox: CGRect,
        orientedImageSize: CGSize,
        previewBounds: CGRect
    ) -> CGRect {
        guard orientedImageSize.width > 0,
              orientedImageSize.height > 0,
              previewBounds.width > 0,
              previewBounds.height > 0 else {
            return .zero
        }

        let imageRect = CGRect(
            x: boundingBox.minX * orientedImageSize.width,
            y: (1 - boundingBox.maxY) * orientedImageSize.height,
            width: boundingBox.width * orientedImageSize.width,
            height: boundingBox.height * orientedImageSize.height
        )

        let scale = max(
            previewBounds.width / orientedImageSize.width,
            previewBounds.height / orientedImageSize.height
        )
        let displayedImageSize = CGSize(
            width: orientedImageSize.width * scale,
            height: orientedImageSize.height * scale
        )
        let imageOrigin = CGPoint(
            x: previewBounds.minX + (previewBounds.width - displayedImageSize.width) / 2,
            y: previewBounds.minY + (previewBounds.height - displayedImageSize.height) / 2
        )

        return CGRect(
            x: imageOrigin.x + imageRect.minX * scale,
            y: imageOrigin.y + imageRect.minY * scale,
            width: imageRect.width * scale,
            height: imageRect.height * scale
        )
    }

    private static func visionRegionOfInterest(
        fromLayerRect layerRect: CGRect,
        orientedImageSize: CGSize,
        previewBounds: CGRect
    ) -> CGRect? {
        guard orientedImageSize.width > 0,
              orientedImageSize.height > 0,
              previewBounds.width > 0,
              previewBounds.height > 0 else {
            return nil
        }

        let scale = max(
            previewBounds.width / orientedImageSize.width,
            previewBounds.height / orientedImageSize.height
        )
        let displayedImageSize = CGSize(
            width: orientedImageSize.width * scale,
            height: orientedImageSize.height * scale
        )
        let imageOrigin = CGPoint(
            x: previewBounds.minX + (previewBounds.width - displayedImageSize.width) / 2,
            y: previewBounds.minY + (previewBounds.height - displayedImageSize.height) / 2
        )
        let displayedImageRect = CGRect(origin: imageOrigin, size: displayedImageSize)
        let clippedLayerRect = layerRect.intersection(displayedImageRect)

        guard !clippedLayerRect.isNull, !clippedLayerRect.isEmpty else {
            return nil
        }

        let imageRect = CGRect(
            x: (clippedLayerRect.minX - imageOrigin.x) / scale,
            y: (clippedLayerRect.minY - imageOrigin.y) / scale,
            width: clippedLayerRect.width / scale,
            height: clippedLayerRect.height / scale
        )
        let imageBounds = CGRect(origin: .zero, size: orientedImageSize)
        let clippedImageRect = imageRect.intersection(imageBounds)

        guard !clippedImageRect.isNull, !clippedImageRect.isEmpty else {
            return nil
        }

        return clampedUnitRect(
            CGRect(
                x: clippedImageRect.minX / orientedImageSize.width,
                y: 1 - (clippedImageRect.maxY / orientedImageSize.height),
                width: clippedImageRect.width / orientedImageSize.width,
                height: clippedImageRect.height / orientedImageSize.height
            )
        )
    }

    private static func fullImageBoundingBox(
        fromRegionRelativeBoundingBox boundingBox: CGRect,
        regionOfInterest: CGRect
    ) -> CGRect {
        clampedUnitRect(
            CGRect(
                x: regionOfInterest.minX + boundingBox.minX * regionOfInterest.width,
                y: regionOfInterest.minY + boundingBox.minY * regionOfInterest.height,
                width: boundingBox.width * regionOfInterest.width,
                height: boundingBox.height * regionOfInterest.height
            )
        )
    }

    private static func clampedUnitRect(_ rect: CGRect) -> CGRect {
        let minX = min(max(rect.minX, 0), 1)
        let minY = min(max(rect.minY, 0), 1)
        let maxX = min(max(rect.maxX, 0), 1)
        let maxY = min(max(rect.maxY, 0), 1)

        return CGRect(
            x: minX,
            y: minY,
            width: max(maxX - minX, 0),
            height: max(maxY - minY, 0)
        )
    }

}
