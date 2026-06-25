import SwiftUI

// "Scientific" meal scan: shows the photo, sweeps a scan line, pops a labeled box
// per detected food, then counts up the calories/macros. Real items from /meal-scan.
struct MealScanView: View {
    let image: UIImage
    let dataB64: String
    var onLogged: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .scanning
    @State private var est: MealEstimate?
    @State private var revealed = 0          // how many item boxes shown
    @State private var counter = 0.0         // 0→1 macro count-up
    @State private var saving = false
    enum Phase { case scanning, done, error }

    // Scattered anchor points for the item boxes (relative to the photo).
    private let anchors: [CGPoint] = [
        .init(x: 0.30, y: 0.32), .init(x: 0.68, y: 0.40), .init(x: 0.42, y: 0.66),
        .init(x: 0.74, y: 0.70), .init(x: 0.24, y: 0.54), .init(x: 0.56, y: 0.24),
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            photo
            Spacer(minLength: 0)
            readout
            controls
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await run() }
    }

    private var header: some View {
        HStack {
            Text(phase == .done ? "Meal scanned" : "Scanning meal")
                .font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                    .padding(8).background(Circle().fill(Theme.card))
            }
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 12)
    }

    private var photo: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: w, height: h).clipped()
                Rectangle().fill(Color.black.opacity(phase == .scanning ? 0.28 : 0.12))

                // corner brackets
                cornerBrackets(w: w, h: h)

                if phase == .scanning {
                    TimelineView(.animation) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        let y = (sin(t * 1.6) * 0.5 + 0.5) * h
                        ZStack {
                            Rectangle().fill(LinearGradient(colors: [.clear, Theme.acc.opacity(0.5), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                                .frame(height: 60).position(x: w / 2, y: y)
                            Rectangle().fill(Theme.acc).frame(height: 2)
                                .shadow(color: Theme.acc, radius: 6).position(x: w / 2, y: y)
                        }
                    }
                }

                // detected-item boxes
                if let est, phase == .done {
                    ForEach(Array(est.items.prefix(anchors.count).enumerated()), id: \.offset) { idx, item in
                        if idx < revealed {
                            itemBox(item).position(x: anchors[idx].x * w, y: anchors[idx].y * h)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .frame(height: 380)
        .padding(.horizontal, 18)
    }

    private func cornerBrackets(w: CGFloat, h: CGFloat) -> some View {
        let len: CGFloat = 26, inset: CGFloat = 14
        return ZStack {
            ForEach(0..<4, id: \.self) { c in
                Path { p in
                    let left = c % 2 == 0, top = c < 2
                    let x = left ? inset : w - inset, y = top ? inset : h - inset
                    p.move(to: .init(x: x, y: y + (top ? len : -len)))
                    p.addLine(to: .init(x: x, y: y))
                    p.addLine(to: .init(x: x + (left ? len : -len), y: y))
                }.stroke(Theme.acc.opacity(0.9), style: .init(lineWidth: 3, lineCap: .round))
            }
        }
    }

    private func itemBox(_ item: MealEstimate.Item) -> some View {
        HStack(spacing: 5) {
            Circle().fill(Theme.acc).frame(width: 5, height: 5)
            Text(item.name).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
            if let p = item.portion, !p.isEmpty {
                Text(p).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.7)).overlay(Capsule().stroke(Theme.acc, lineWidth: 1)))
    }

    private var readout: some View {
        VStack(spacing: 10) {
            if phase == .scanning {
                Text("Identifying foods…").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut)
            } else if phase == .error {
                Text("Couldn't read that one — try a clearer photo.").font(.system(size: 13)).foregroundStyle(Theme.red)
            } else if let est {
                Text(est.name).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                    .multilineTextAlignment(.center)
                HStack(spacing: 22) {
                    macro("\(Int((est.calories * counter).rounded()))", "cal", Theme.acc)
                    macro("\(Int((est.protein_g * counter).rounded()))g", "protein", Theme.txt)
                    macro("\(Int((est.carbs_g * counter).rounded()))g", "carbs", Theme.txt)
                    macro("\(Int((est.fat_g * counter).rounded()))g", "fat", Theme.txt)
                }
                if est.confidence.lowercased() == "low" {
                    Text("Low confidence — tweak it after adding if needed.").font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.top, 14)
    }

    private func macro(_ v: String, _ k: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 18, weight: .heavy)).foregroundStyle(c)
            Text(k).font(.system(size: 10)).foregroundStyle(Theme.mut)
        }
    }

    @ViewBuilder private var controls: some View {
        if phase == .done {
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Discard").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card)).foregroundStyle(Theme.txt)
                }
                Button { Task { await add() } } label: {
                    HStack(spacing: 6) {
                        if saving { ProgressView().tint(Color(hex: 0x0E0E10)) }
                        Text("Add to today").font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
                }
                .disabled(saving)
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 14)
        } else if phase == .error {
            Button { dismiss() } label: {
                Text("Close").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card)).foregroundStyle(Theme.txt)
            }
            .padding(.horizontal, 18).padding(.bottom, 14)
        } else {
            Color.clear.frame(height: 70)
        }
    }

    // MARK: flow
    private func run() async {
        do {
            let result = try await ScanAPI.shared.scanMeal(.init(mimeType: "image/jpeg", dataB64: dataB64))
            est = result
            withAnimation(.easeOut(duration: 0.3)) { phase = .done }
            // pop item boxes one at a time
            let n = min(result.items.count, anchors.count)
            for i in 1...max(1, n) {
                try? await Task.sleep(nanoseconds: 260_000_000)
                withAnimation(.spring(response: 0.35)) { revealed = i }
            }
            // count up macros
            let steps = 26
            for i in 0...steps {
                counter = Double(i) / Double(steps)
                try? await Task.sleep(nanoseconds: 28_000_000)
            }
            counter = 1
        } catch {
            withAnimation { phase = .error }
        }
    }

    private func add() async {
        guard let est else { return }
        saving = true
        try? await ScanAPI.shared.logMeal(est)
        await MainActor.run { saving = false; onLogged(); dismiss() }
    }
}
