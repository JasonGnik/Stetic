import SwiftUI
import AVFoundation
import PhotosUI

// Cal AI-style capture: live camera with three modes (Scan Food / Barcode / Food
// Label), Stetic branding, an accuracy "?", flash, capture button, and a photo-library
// shortcut. Barcode mode auto-detects; the other two capture a photo.
enum FoodScanMode: String, CaseIterable, Identifiable {
    case scanFood, barcode, foodLabel
    var id: String { rawValue }
    var label: String {
        switch self { case .scanFood: return "Scan Food"; case .barcode: return "Barcode"; case .foodLabel: return "Food Label" }
    }
    var icon: String {
        switch self { case .scanFood: return "viewfinder"; case .barcode: return "barcode.viewfinder"; case .foodLabel: return "doc.text.viewfinder" }
    }
}

struct FoodCameraView: View {
    var onCapture: (UIImage, FoodScanMode) -> Void
    var onBarcode: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var cam = CameraController()
    @State private var mode: FoodScanMode = .scanFood
    @State private var libItem: PhotosPickerItem?
    @State private var showHelp = false
    @State private var denied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if cam.available { CameraPreview(session: cam.session).ignoresSafeArea() }
            overlay
        }
        .task { await setup() }
        .onDisappear { cam.stop() }
        .onChange(of: mode) { _, m in cam.mode = m }
        .onChange(of: libItem) { _, v in Task { await loadLibrary(v) } }
        .alert("Heads up", isPresented: $showHelp) {
            Button("Got it", role: .cancel) {}
        } message: { Text("Scans aren't always 100% accurate — you can edit anything after it scans.") }
        .statusBarHidden(true)
    }

    // MARK: overlay
    private var overlay: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            reticle
            Spacer()
            bottom
        }
    }

    private var topBar: some View {
        HStack {
            iconButton("xmark") { dismiss() }
            Spacer()
            Text("STETIC").font(.system(size: 16, weight: .heavy)).tracking(3).foregroundStyle(Theme.acc)
            Spacer()
            iconButton("questionmark") { showHelp = true }
        }
        .padding(.horizontal, 18).padding(.top, 14)
    }

    @ViewBuilder private var reticle: some View {
        let w: CGFloat = mode == .barcode ? 260 : 290
        let h: CGFloat = mode == .barcode ? 150 : 290
        ZStack {
            RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.85), lineWidth: 2).frame(width: w, height: h)
            if !cam.available {
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.8))
                    Text(denied ? "Enable camera in Settings" : "Camera unavailable here")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                    Text("Use the photo button below").font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                }
            } else if mode == .barcode {
                Text("Point at a barcode").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                    .offset(y: h / 2 + 22)
            }
        }
    }

    private var bottom: some View {
        VStack(spacing: 18) {
            // mode selector
            HStack(spacing: 8) {
                ForEach(FoodScanMode.allCases) { m in
                    Button { mode = m } label: {
                        HStack(spacing: 6) {
                            Image(systemName: m.icon).font(.system(size: 12, weight: .bold))
                            Text(m.label).font(.system(size: 12.5, weight: .bold))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Capsule().fill(mode == m ? Color.white : Color.white.opacity(0.14)))
                        .foregroundStyle(mode == m ? .black : .white)
                    }
                }
            }
            // controls
            HStack {
                Button { cam.toggleFlash() } label: {
                    Image(systemName: cam.flashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 18)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(Circle().fill(.white.opacity(0.14)))
                }
                Spacer()
                Button { if cam.available && mode != .barcode { cam.capture() } } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 74, height: 74)
                        Circle().fill(.white).frame(width: 60, height: 60)
                    }
                    .opacity(mode == .barcode ? 0.4 : 1)
                }
                .disabled(mode == .barcode || !cam.available)
                Spacer()
                PhotosPicker(selection: $libItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle").font(.system(size: 18)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(Circle().fill(.white.opacity(0.14)))
                }
            }
            .padding(.horizontal, 30)
        }
        .padding(.bottom, 28)
    }

    private func iconButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .frame(width: 38, height: 38).background(Circle().fill(.black.opacity(0.4)))
        }
    }

    // MARK: wiring
    private func setup() async {
        cam.onPhoto = { img in onCapture(img, mode); dismiss() }
        cam.onBarcode = { code in onBarcode(code); dismiss() }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { denied = true; return }
        } else if status == .denied || status == .restricted {
            denied = true; return
        }
        cam.configure(); cam.mode = mode; cam.start()
    }

    private func loadLibrary(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else { return }
        onCapture(img, mode == .barcode ? .scanFood : mode)
        dismiss()
    }
}

// MARK: - AVFoundation
final class CameraController: NSObject, ObservableObject,
    AVCapturePhotoCaptureDelegate, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var device: AVCaptureDevice?
    private var configured = false
    private var lastBarcodeAt = Date.distantPast

    @Published var available = false
    @Published var flashOn = false
    var onPhoto: ((UIImage) -> Void)?
    var onBarcode: ((String) -> Void)?
    var mode: FoodScanMode = .scanFood { didSet { applyMetadataTypes() } }
    private static let barcodeTypes: [AVMetadataObject.ObjectType] = [.ean8, .ean13, .upce, .code128, .code39, .qr]

    // Only set types the connected output actually supports — setting an unsupported
    // type (or any type before the output is wired) throws an NSException → crash.
    private func applyMetadataTypes() {
        guard configured else { metadataOutput.metadataObjectTypes = []; return }
        let wanted = mode == .barcode ? Self.barcodeTypes : []
        metadataOutput.metadataObjectTypes = wanted.filter { metadataOutput.availableMetadataObjectTypes.contains($0) }
    }

    func configure() {
        guard !configured else { return }
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam) else { available = false; return }
        device = cam
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = []
        }
        session.commitConfiguration()
        configured = true
        available = true
        applyMetadataTypes()   // now that the output is wired, honor the current mode
    }

    func start() { guard available, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    func stop() { if session.isRunning { session.stopRunning() } }

    func capture() {
        guard available else { return }
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashOn ? .on : .off) { settings.flashMode = flashOn ? .on : .off }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleFlash() { flashOn.toggle() }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let img = UIImage(data: data) else { return }
        onPhoto?(img)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard mode == .barcode,
              let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue,
              Date().timeIntervalSince(lastBarcodeAt) > 2 else { return }
        lastBarcodeAt = Date()
        onBarcode?(code)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
