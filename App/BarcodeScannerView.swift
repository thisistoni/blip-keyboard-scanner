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
    /// Batch scans keep scanning and add every code in view.
    var continuesScanning = false
    /// Batch scans only: how many more codes the list can take. At 0 frames are
    /// still analysed so codes in view stay blocked, but nothing is added.
    var batchCapacity = Int.max
    @Binding var isTorchAvailable: Bool
    @Binding var isTorchOn: Bool
    @Binding var statusMessage: String?
    @Binding var currentZoomFactor: Double
    @Binding var selectableCodeCount: Int
    /// Lets a SwiftUI tap gesture on this view reach the controller as well.
    var tapRelay: BarcodeScannerTapRelay? = nil
    let onCode: (ScannerCodeResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCode: onCode,
            isTorchAvailable: $isTorchAvailable,
            isTorchOn: $isTorchOn,
            statusMessage: $statusMessage,
            currentZoomFactor: $currentZoomFactor,
            selectableCodeCount: $selectableCodeCount
        )
    }

    func makeUIViewController(context: Context) -> BarcodeCaptureViewController {
        let controller = BarcodeCaptureViewController()
        controller.delegate = context.coordinator
        controller.scanFormatProfile = scanFormatProfile
        controller.defaultZoomFactor = defaultZoomFactor
        controller.scanArea = scanArea
        controller.continuesScanning = continuesScanning
        controller.batchCapacity = batchCapacity
        controller.setTorch(on: flashlightMode == .on)
        tapRelay?.controller = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeCaptureViewController, context: Context) {
        context.coordinator.onCode = onCode
        uiViewController.scanFormatProfile = scanFormatProfile
        uiViewController.defaultZoomFactor = defaultZoomFactor
        uiViewController.scanArea = scanArea
        uiViewController.continuesScanning = continuesScanning
        uiViewController.batchCapacity = batchCapacity
        uiViewController.setTorch(on: flashlightMode == .on)
        tapRelay?.controller = uiViewController
    }

    static func dismantleUIViewController(_ uiViewController: BarcodeCaptureViewController, coordinator: Coordinator) {
        uiViewController.setTorch(on: false)
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, BarcodeCaptureViewControllerDelegate {
        var onCode: (ScannerCodeResult) -> Void
        private var isTorchAvailable: Binding<Bool>
        private var isTorchOn: Binding<Bool>
        private var statusMessage: Binding<String?>
        private var currentZoomFactor: Binding<Double>
        private var selectableCodeCount: Binding<Int>

        init(
            onCode: @escaping (ScannerCodeResult) -> Void,
            isTorchAvailable: Binding<Bool>,
            isTorchOn: Binding<Bool>,
            statusMessage: Binding<String?>,
            currentZoomFactor: Binding<Double>,
            selectableCodeCount: Binding<Int>
        ) {
            self.onCode = onCode
            self.isTorchAvailable = isTorchAvailable
            self.isTorchOn = isTorchOn
            self.statusMessage = statusMessage
            self.currentZoomFactor = currentZoomFactor
            self.selectableCodeCount = selectableCodeCount
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

        func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateSelectableCodeCount count: Int) {
            selectableCodeCount.wrappedValue = count
        }
    }
}

/// Forwards taps recognised by SwiftUI on `BarcodeScannerView` (in the
/// controller view's coordinates) to the capture controller. The controller
/// also has its own UIKit tap recognizer; it drops the second delivery of the
/// same tap, so a tap arriving through both paths selects only once.
final class BarcodeScannerTapRelay {
    weak var controller: BarcodeCaptureViewController?

    func tap(at point: CGPoint) {
        controller?.handleTap(at: point, source: .swiftUI)
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
    /// Number of outlined codes the user can tap; 0 when no choice is pending.
    func barcodeCaptureViewController(_ controller: BarcodeCaptureViewController, didUpdateSelectableCodeCount count: Int)
}

final class BarcodeCaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UIGestureRecognizerDelegate {
    enum TapSource: String {
        case uiKit
        case swiftUI
    }

    /// Two deliveries of one tap (UIKit and SwiftUI) arrive within a few
    /// milliseconds at the same point; a real second tap comes through the same
    /// path again and is never filtered, however quickly it follows.
    private static let duplicateTapInterval: TimeInterval = 0.15
    private static let duplicateTapDistance: CGFloat = 30

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
    /// Batch scanning: every code in view is added and scanning continues.
    /// Changing it starts afresh (only done while no batch code is collected).
    var continuesScanning = false {
        didSet {
            guard oldValue != continuesScanning else { return }
            let continues = continuesScanning
            visionQueue.async { [weak self] in
                guard let self, !self.didScan else { return }
                self.selectionTracker = BarcodeSelectionTracker()
                self.batchTracker = continues ? BarcodeBatchTracker() : nil
                self.lastKnownCandidateRects.removeAll()
                self.presentCandidates([])
            }
        }
    }
    /// Batch scanning: how many more codes the list can take.
    var batchCapacity = Int.max {
        didSet {
            guard oldValue != batchCapacity else { return }
            let capacity = batchCapacity
            visionQueue.async { [weak self] in
                self?.remainingBatchCapacity = capacity
            }
        }
    }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.antoniobeslic.Blip.camera")
    private let visionQueue = DispatchQueue(label: "com.antoniobeslic.Blip.vision")
    private let frameQueue = DispatchQueue(label: "com.antoniobeslic.Blip.frames")
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
    private var activeVisionScanRect: CGRect?
    private var latestDetectionRegionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var latestAcceptanceRegionOfInterest: CGRect?

    // Multi-code selection. The trackers, frame metadata, `didScan` and
    // `remainingBatchCapacity` are only touched on `visionQueue`; the overlay
    // and accessibility state on main.
    private var selectionTracker = BarcodeSelectionTracker()
    /// Set while batch scanning; then `selectionTracker` is unused.
    private var batchTracker: BarcodeBatchTracker?
    /// Counted down as codes are delivered and reset from SwiftUI as the list
    /// changes, so a frame never delivers more codes than the list can take.
    private var remainingBatchCapacity = Int.max
    private var latestFrameTimestamp: TimeInterval = 0
    private var latestBufferIsPortrait = true
    private var lastKnownCandidateRects: [BarcodeCandidateKey: CGRect] = [:]
    private var isPresentingCandidates = false
    private let candidateOverlay = BarcodeCandidateOverlayView()
    private var candidateAccessibilityElements: [BarcodeCandidateKey: BarcodeCandidateAccessibilityElement] = [:]
    private var publishedSelectableCodeCount = 0
    private var lastTap: (time: TimeInterval, point: CGPoint, source: TapSource)?

    static func defaultVideoDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configurePreviewLayer()
        configureCandidateOverlay()
        configurePinchGesture()
        configureTapGesture()
        configureVision()
        requestCameraAccessAndConfigure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        candidateOverlay.frame = view.bounds
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

    private func configureCandidateOverlay() {
        // Taps and pinches go to `view`'s recognizers; the overlay only draws.
        candidateOverlay.isUserInteractionEnabled = false
        candidateOverlay.frame = view.bounds
        view.addSubview(candidateOverlay)
    }

    private func configureTapGesture() {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        // Never let this recognizer block (or be blocked by) SwiftUI's own
        // gesture recognizers or the pinch; duplicates are filtered in `handleTap`.
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        view.addGestureRecognizer(recognizer)
    }

    @objc private func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        handleTap(at: recognizer.location(in: candidateOverlay), source: .uiKit)
    }

    /// Main thread. `point` is in this controller's view (and overlay) coordinates.
    func handleTap(at point: CGPoint, source: TapSource) {
        let now = ProcessInfo.processInfo.systemUptime
        if let lastTap, lastTap.source != source,
           now - lastTap.time < Self.duplicateTapInterval,
           hypot(lastTap.point.x - point.x, lastTap.point.y - point.y) < Self.duplicateTapDistance {
            return
        }
        lastTap = (now, point, source)

        let key = candidateOverlay.candidate(at: point)
        guard let key else { return }
        selectCandidate(key)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
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
        var symbologies = scanFormatProfile.visionSymbologies
        if !symbologies.contains(.qr) { symbologies.append(.qr) }
        barcodeRequest?.symbologies = symbologies
    }

    private func updateScanAreaRegion() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let visionScanRect: CGRect?
            if self.scanArea == .centeredBox, let previewLayer = self.previewLayer {
                let layerRect = ScannerScanAreaGuide.rect(in: previewLayer.bounds)
                let metadataRect = previewLayer.metadataOutputRectConverted(fromLayerRect: layerRect)
                visionScanRect = Self.visionRect(fromMetadataRect: metadataRect)
            } else {
                visionScanRect = nil
            }

            self.scanAreaLock.lock()
            self.activeVisionScanRect = visionScanRect
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
                // Video-only scanning must not replace the beep's mixing policy.
                self.session.automaticallyConfiguresApplicationAudioSession = false
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
                self.videoOutput.setSampleBufferDelegate(self, queue: self.frameQueue)

                guard self.session.canAddOutput(self.videoOutput) else {
                    self.session.commitConfiguration()
                    self.updateStatus(NSLocalizedString("Camera output unavailable", comment: "Camera output unavailable status"))
                    return
                }
                self.session.addOutput(self.videoOutput)

                // 4K frames when the camera supports them: at 1080p (`.high`) an
                // iPhone 16 Pro Max could not decode two EAN-13 product codes side
                // by side (one decoded now and then, the other never); at 4K both
                // decoded at ~31 analysed frames/s. Checked after the input and
                // output are attached, because support depends on them. Zoom
                // limits come from the active format, and the scan-area and
                // outline maths use normalised coordinates, so neither depends on
                // the preset.
                if self.session.canSetSessionPreset(.hd4K3840x2160) {
                    self.session.sessionPreset = .hd4K3840x2160
                }

                if let connection = self.videoOutput.connection(with: .video),
                   connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }

                self.session.commitConfiguration()

                // Barcodes are scanned up close: keep continuous autofocus in the
                // near range so it does not hunt to the background, and turn off
                // smooth (slow, video-oriented) focus ramps.
                if (try? device.lockForConfiguration()) != nil {
                    if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
                    if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
                    if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = false }
                    device.unlockForConfiguration()
                }

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
        // Frames arrive on `frameQueue` and take turns on `visionQueue` with taps
        // and setting changes. Delivering frames straight onto `visionQueue`
        // starved those: on device a tap waited seconds until no code was in view.
        visionQueue.sync {
            analyse(sampleBuffer)
        }
    }

    /// Runs on `visionQueue`.
    private func analyse(_ sampleBuffer: CMSampleBuffer) {
        guard !didScan, !isProcessingFrame, let barcodeRequest else { return }

        isProcessingFrame = true
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        latestFrameTimestamp = presentationTime.isNumeric
            ? presentationTime.seconds
            : ProcessInfo.processInfo.systemUptime
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            latestBufferIsPortrait = CVPixelBufferGetHeight(pixelBuffer) >= CVPixelBufferGetWidth(pixelBuffer)
        }
        latestAcceptanceRegionOfInterest = currentActiveVisionScanRect()
        latestDetectionRegionOfInterest = latestAcceptanceRegionOfInterest.map {
            Self.expandedVisionRect($0, paddingRatio: 0.18)
        } ?? Self.fullVisionRegion
        barcodeRequest.regionOfInterest = latestDetectionRegionOfInterest

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

        // Every distinct code that passes the existing filters, in Vision's order.
        var frameCandidates: [BarcodeCandidateKey] = []
        var frameRects: [BarcodeCandidateKey: CGRect] = [:]
        for observation in request.results?.compactMap({ $0 as? VNBarcodeObservation }) ?? [] {
            guard let value = observation.payloadStringValue else { continue }
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if observation.symbology == .qr,
               !BlipCompanyProfileQR.acceptsScannedQR(value, formatProfile: scanFormatProfile) {
                continue
            }
            guard isObservationInsideActiveScanArea(
                observation,
                detectionRegionOfInterest: latestDetectionRegionOfInterest,
                acceptanceRegionOfInterest: latestAcceptanceRegionOfInterest
            ) else { continue }

            let key = BarcodeCandidateKey(value: value, symbology: observation.symbology.rawValue)
            guard frameRects[key] == nil else { continue }
            frameCandidates.append(key)
            frameRects[key] = Self.fullImageBoundingBox(
                fromRegionRelativeBoundingBox: observation.boundingBox,
                regionOfInterest: latestDetectionRegionOfInterest
            )
        }

        if var batch = batchTracker {
            // Batch: every code is confirmed on its own and added; no choice.
            // A full list (capacity 0) still feeds frames so codes in view stay
            // blocked, and ready codes beyond the capacity wait.
            let added = batch.process(frameCandidates, at: latestFrameTimestamp, capacity: max(remainingBatchCapacity, 0))
            batchTracker = batch
            remainingBatchCapacity -= added.count
            presentBatchOutlines(frameRects, tracker: batch)
            // One delivery per code, in order; each gets its sound and row.
            for key in added {
                deliverResult(for: key, highlightingSelection: false)
            }
            return
        }

        let decision = selectionTracker.process(frameCandidates, at: latestFrameTimestamp)
        switch decision {
        case .waiting:
            lastKnownCandidateRects.removeAll()
            presentCandidates([])
        case .accept(let key):
            didScan = true
            lastKnownCandidateRects.removeAll()
            presentCandidates([])
            deliverResult(for: key, highlightingSelection: false)
        case .choose(let keys):
            lastKnownCandidateRects.merge(frameRects) { _, newRect in newRect }
            // Codes Vision skipped this frame keep their last outline until they expire.
            let offered = keys.compactMap { key in lastKnownCandidateRects[key].map { (key, $0) } }
            lastKnownCandidateRects = Dictionary(uniqueKeysWithValues: offered)
            presentCandidates(offered)
        }
    }

    /// Vision queue, batch only. Added codes reported within the retention
    /// window keep a dashed "added" outline; codes still confirming get a thin
    /// neutral one. Neither can be tapped.
    private func presentBatchOutlines(_ frameRects: [BarcodeCandidateKey: CGRect], tracker: BarcodeBatchTracker) {
        lastKnownCandidateRects.merge(frameRects) { _, newRect in newRect }
        let added = tracker.visibleAddedKeys.sorted { ($0.value, $0.symbology) < ($1.value, $1.symbology) }
        var styles: [BarcodeCandidateKey: BarcodeCandidateOverlayView.Style] = [:]
        for key in added { styles[key] = .added }
        for key in tracker.confirmingKeys { styles[key] = .confirming }
        let visible = (tracker.confirmingKeys + added).compactMap { key in
            lastKnownCandidateRects[key].map { (key, $0) }
        }
        lastKnownCandidateRects = Dictionary(uniqueKeysWithValues: visible)
        presentCandidates(visible, styles: styles)
    }

    /// Runs on `visionQueue`. Hops to main with Vision-space rects for the overlay.
    private func presentCandidates(
        _ candidates: [(BarcodeCandidateKey, CGRect)],
        styles: [BarcodeCandidateKey: BarcodeCandidateOverlayView.Style] = [:]
    ) {
        guard !candidates.isEmpty || isPresentingCandidates else { return }
        isPresentingCandidates = !candidates.isEmpty
        let bufferIsPortrait = latestBufferIsPortrait

        DispatchQueue.main.async { [weak self] in
            guard let self, let previewLayer = self.previewLayer else { return }
            let displayed = candidates.map { key, visionRect in
                BarcodeCandidateOverlayView.Candidate(
                    key: key,
                    rect: previewLayer.layerRectConverted(
                        fromMetadataOutputRect: Self.metadataRect(
                            fromVisionRect: visionRect,
                            bufferIsPortrait: bufferIsPortrait
                        )
                    ),
                    style: styles[key] ?? .selectable
                )
            }
            self.candidateOverlay.update(displayed)
            // VoiceOver frames follow the smoothed rects that are drawn and tapped.
            self.updateCandidateAccessibility(self.candidateOverlay.candidates)
        }
    }

    /// Main thread. The tap is resolved on `visionQueue` so it cannot race an auto-accept.
    private func selectCandidate(_ key: BarcodeCandidateKey) {
        visionQueue.async { [weak self] in
            // Batch scans have no choice to make and nothing to tap.
            guard let self, !self.didScan, self.batchTracker == nil,
                  self.selectionTracker.select(key) else { return }
            self.didScan = true
            self.isPresentingCandidates = false
            self.lastKnownCandidateRects.removeAll()
            self.deliverResult(for: key, highlightingSelection: true)
        }
    }

    private func deliverResult(for key: BarcodeCandidateKey, highlightingSelection: Bool) {
        let result = ScannerCodeResult(
            value: key.value,
            codeFormat: key.symbology,
            isManualEntry: false
        )
        let continues = batchTracker != nil

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if highlightingSelection {
                self.candidateOverlay.highlight(key)
            }
            if !continues {
                self.updateCandidateAccessibility([])
            }
            self.delegate?.barcodeCaptureViewController(self, didScan: result)
        }
    }

    private func updateCandidateAccessibility(_ candidates: [BarcodeCandidateOverlayView.Candidate]) {
        let previousKeys = Set(candidateAccessibilityElements.keys)
        var elements: [BarcodeCandidateAccessibilityElement] = []
        var elementsByKey: [BarcodeCandidateKey: BarcodeCandidateAccessibilityElement] = [:]
        var selectableCount = 0

        for candidate in candidates {
            let element = candidateAccessibilityElements[candidate.key]
                ?? BarcodeCandidateAccessibilityElement(accessibilityContainer: view as Any)
            let label = "\(candidate.key.value), \(ScanHistoryItem.displayName(forCodeFormat: candidate.key.symbology))"
            switch candidate.style {
            case .confirming:
                // Not added yet and not interactive; announced once it is added.
                continue
            case .added:
                element.accessibilityLabel = String(
                    format: NSLocalizedString("%@, added", comment: "Outlined code already in the batch list; %@ is the code and its format"),
                    label
                )
                element.accessibilityHint = nil
                element.accessibilityTraits = .staticText
                element.onActivate = nil
            case .selectable:
                element.accessibilityLabel = label
                element.accessibilityHint = NSLocalizedString("Uses this code.", comment: "Selectable scanned code accessibility hint")
                element.accessibilityTraits = .button
                element.onActivate = { [weak self] in self?.selectCandidate(candidate.key) }
                selectableCount += 1
            }
            element.accessibilityFrameInContainerSpace = BarcodeCandidateOverlayView.tapTarget(for: candidate.rect)
            elements.append(element)
            elementsByKey[candidate.key] = element
        }

        candidateAccessibilityElements = elementsByKey
        view.accessibilityElements = elements.isEmpty ? nil : elements

        if Set(elementsByKey.keys) != previousKeys {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
        if publishedSelectableCodeCount == 0, selectableCount > 0 {
            UIAccessibility.post(
                notification: .announcement,
                argument: NSLocalizedString(
                    "Several codes found. Select the code you want to use.",
                    comment: "VoiceOver announcement when several codes are visible"
                )
            )
        }
        if publishedSelectableCodeCount != selectableCount {
            publishedSelectableCodeCount = selectableCount
            delegate?.barcodeCaptureViewController(self, didUpdateSelectableCodeCount: selectableCount)
        }
    }

    private func isObservationInsideActiveScanArea(
        _ observation: VNBarcodeObservation,
        detectionRegionOfInterest: CGRect,
        acceptanceRegionOfInterest: CGRect?
    ) -> Bool {
        guard let acceptanceRegionOfInterest else {
            return true
        }

        let fullImageBoundingBox = Self.fullImageBoundingBox(
            fromRegionRelativeBoundingBox: observation.boundingBox,
            regionOfInterest: detectionRegionOfInterest
        )
        let observationCenter = CGPoint(
            x: fullImageBoundingBox.midX,
            y: fullImageBoundingBox.midY
        )

        return acceptanceRegionOfInterest.contains(observationCenter)
    }

    private func currentActiveVisionScanRect() -> CGRect? {
        scanAreaLock.lock()
        defer { scanAreaLock.unlock() }
        return activeVisionScanRect
    }

    private static func visionRect(fromMetadataRect rect: CGRect) -> CGRect {
        return clampedUnitRect(
            CGRect(
                x: rect.minX,
                y: 1 - rect.maxY,
                width: rect.width,
                height: rect.height
            )
        )
    }

    /// Maps a full-image Vision rect (lower-left origin, in the `.right`-oriented
    /// image Vision analyses) to capture metadata coordinates (upper-left origin,
    /// unrotated sensor), which the preview layer converts with its aspect fill.
    private static func metadataRect(fromVisionRect rect: CGRect, bufferIsPortrait: Bool) -> CGRect {
        if bufferIsPortrait {
            // The connection already rotated the buffer to portrait and `.right`
            // turns it once more, so Vision x runs against the sensor's x axis
            // while Vision y (upwards) runs along the sensor's y axis (downwards).
            return CGRect(x: 1 - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
        }
        // Unrotated sensor buffer: `.right` yields the portrait image, swapping the axes.
        return CGRect(x: 1 - rect.maxY, y: 1 - rect.maxX, width: rect.height, height: rect.width)
    }

    private static func expandedVisionRect(_ rect: CGRect, paddingRatio: CGFloat) -> CGRect {
        let horizontalPadding = rect.width * paddingRatio
        let verticalPadding = rect.height * paddingRatio

        return clampedUnitRect(
            rect.insetBy(dx: -horizontalPadding, dy: -verticalPadding)
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
