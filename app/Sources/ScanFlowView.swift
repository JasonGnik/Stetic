import SwiftUI
import PhotosUI

struct ScanFlowView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var uiImage: UIImage?
    @State private var phase: Phase = .idle
    @State private var card: ScoreCard?
    @State private var didAutoScan = false
    @State private var showPlan = false

    enum Phase: Equatable { case idle, scanning, result, error(String) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            switch phase {
            case .scanning:
                ScanningLoader(
                    title: "Analyzing your physique",
                    messages: ["Mapping your physique", "Reading proportions & symmetry",
                               "Estimating body composition", "Calibrating your ratios", "Scoring aesthetics"]
                )
            case .result:
                if let card {
                    VStack(spacing: 0) {
                        ScoreCardView(card: card) { showPlan = true }
                        Button("Scan another") { reset() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.mut)
                            .padding(.bottom, 8)
                    }
                    .fullScreenCover(isPresented: $showPlan) { PlanView() }
                }
            default:
                capture
            }
        }
    }

    private var capture: some View {
        VStack(spacing: 22) {
            Spacer()
            VStack(spacing: 6) {
                Text("STETIC")
                    .font(.system(size: 30, weight: .heavy)).tracking(3)
                    .foregroundStyle(Theme.txt)
                Text("Scan your physique")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.mut)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1))
                if let uiImage {
                    Image(uiImage: uiImage).resizable().scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.arms.open").font(.system(size: 40)).foregroundStyle(Theme.mut)
                        Text("Front-facing, athletic wear").font(.system(size: 12)).foregroundStyle(Theme.mut)
                    }
                }
            }
            .frame(width: 220, height: 300)

            if case .error(let msg) = phase {
                Text(msg).font(.system(size: 12)).foregroundStyle(Theme.red)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }

            VStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(uiImage == nil ? "Choose photo" : "Choose different photo")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .frame(maxWidth: .infinity).padding(13)
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                }

                Button(action: scan) {
                    HStack(spacing: 8) {
                        if phase == .scanning { ProgressView().tint(Color(hex: 0x0E0E10)) }
                        Text(phase == .scanning ? "Analyzing…" : "Scan my physique")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(uiImage == nil ? Theme.line : Theme.acc))
                    .foregroundStyle(uiImage == nil ? Theme.mut : Color(hex: 0x0E0E10))
                }
                .disabled(uiImage == nil || phase == .scanning)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .onChange(of: pickerItem) { _, newItem in
            Task { await load(newItem) }
        }
        .task {
            // DEV: auto-scan a bundled sample ONCE per launch to verify the live path.
            if !didAutoScan, phase == .idle,
               ProcessInfo.processInfo.environment["STETIC_AUTOSCAN"] == "1",
               let url = Bundle.main.url(forResource: "sample", withExtension: "jpg"),
               let data = try? Data(contentsOf: url) {
                didAutoScan = true
                imageData = data
                uiImage = UIImage(data: data)
                scan()
            }
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        imageData = data
        uiImage = UIImage(data: data)
        if case .error = phase { phase = .idle }
    }

    private func scan() {
        guard let data = imageData else { return }
        phase = .scanning
        Task {
            do {
                let jpeg = UIImage(data: data)?.jpegData(compressionQuality: 0.85) ?? data
                let input = ScanAPI.ImageInput(mimeType: "image/jpeg", dataB64: jpeg.base64EncodedString())
                let result = try await ScanAPI.shared.scan(images: [input])
                await MainActor.run { card = result; phase = .result }
            } catch {
                await MainActor.run { phase = .error(error.localizedDescription) }
            }
        }
    }

    private func reset() {
        card = nil; uiImage = nil; imageData = nil; pickerItem = nil; phase = .idle
    }
}
