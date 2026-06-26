import SwiftUI

// "I'm craving X" → an AI fix tuned by how badly they want it (lightly → mildly →
// badly), respecting the day's remaining macros. 80/20: enjoy it, stay on track.
struct CravingView: View {
    var target: PlanContent.Macros?
    var consumed: (cals: Double, p: Double, c: Double, f: Double)
    var goal: String = ""
    var onLog: (MealEstimate) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var intensity: Double = 1
    @State private var loading = false
    @State private var result: CravingResult?
    @State private var error: String?

    private let chips = ["Burger", "Pizza", "Sweet treat", "Chocolate", "Fries", "Ice cream", "Tacos", "Wings"]
    private let levels = ["lightly", "mildly", "badly"]
    private var intensityWord: String { ["A little", "Pretty bad", "SO bad"][Int(intensity)] }

    private var remaining: (cals: Double, p: Double, c: Double, f: Double) {
        guard let t = target else { return (0, 0, 0, 0) }
        return (max(0, t.calories - consumed.cals), max(0, t.protein_g - consumed.p),
                max(0, t.carbs_g - consumed.c), max(0, t.fat_g - consumed.f))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Craving something?").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                        .padding(8).background(Circle().fill(Theme.card))
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tell us what you want — we'll make it fit. You don't have to be perfect, just smart about it.")
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut).lineSpacing(2)

                    TextField("", text: $text, prompt: Text("What are you craving?").foregroundStyle(Theme.mut))
                        .font(.system(size: 16)).foregroundStyle(Theme.txt).padding(13)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(chips, id: \.self) { c in
                                Button { text = c } label: {
                                    Text(c).font(.system(size: 12.5, weight: .semibold))
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(Capsule().fill(text == c ? Theme.acc : Theme.card).overlay(Capsule().stroke(Theme.line, lineWidth: text == c ? 0 : 1)))
                                        .foregroundStyle(text == c ? Color(hex: 0x0E0E10) : Theme.txt)
                                }
                            }
                        }
                    }

                    // intensity slider
                    VStack(spacing: 8) {
                        HStack {
                            Text("How bad is it?").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                            Spacer()
                            Text(intensityWord).font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.acc)
                        }
                        Slider(value: $intensity, in: 0...2, step: 1).tint(Theme.acc)
                        HStack {
                            Text("Lightly").font(.system(size: 11)).foregroundStyle(Theme.mut)
                            Spacer(); Text("Mildly").font(.system(size: 11)).foregroundStyle(Theme.mut)
                            Spacer(); Text("Badly").font(.system(size: 11)).foregroundStyle(Theme.mut)
                        }
                        Text(["We'll keep the flavor, cut the damage (think burger bowl).",
                              "A lighter homemade version of the real thing.",
                              "The real deal — and how to fit it in."][Int(intensity)])
                            .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1)))

                    Button { Task { await fetch() } } label: {
                        HStack(spacing: 8) {
                            if loading { ProgressView().tint(Color(hex: 0x0E0E10)) }
                            Image(systemName: "wand.and.stars").font(.system(size: 15, weight: .bold))
                            Text(loading ? "Cooking it up…" : "Get my fix").font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity).padding(14)
                        .background(RoundedRectangle(cornerRadius: 13).fill(canFetch ? Theme.acc : Theme.line))
                        .foregroundStyle(canFetch ? Color(hex: 0x0E0E10) : Theme.mut)
                    }
                    .disabled(!canFetch || loading)

                    if let error { Text(error).font(.system(size: 12)).foregroundStyle(Theme.red) }
                    if let result { resultCard(result) }
                }
                .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private var canFetch: Bool { text.trimmingCharacters(in: .whitespaces).count >= 2 }

    private func resultCard(_ r: CravingResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(r.name).font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                    if !r.portion.isEmpty { Text(r.portion).font(.system(size: 12)).foregroundStyle(Theme.mut) }
                }
                Spacer()
                if !r.version.isEmpty {
                    Text(r.version).font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Theme.acc.opacity(0.16))).foregroundStyle(Theme.acc)
                }
            }
            HStack(spacing: 8) {
                macro("Cals", "\(Int(r.calories))"); macro("P", "\(Int(r.protein_g))g")
                macro("C", "\(Int(r.carbs_g))g"); macro("F", "\(Int(r.fat_g))g")
            }
            if !r.fit_tip.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 13)).foregroundStyle(Theme.acc).padding(.top, 1)
                    Text(r.fit_tip).font(.system(size: 12.5)).foregroundStyle(Color(hex: 0xD2D2D8)).lineSpacing(2)
                }
            }
            if !r.adjustments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TO MAKE ROOM").font(.system(size: 9.5, weight: .bold)).tracking(0.5).foregroundStyle(Theme.mut)
                    ForEach(r.adjustments, id: \.self) { a in
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.acc).padding(.top, 3)
                            Text(a).font(.system(size: 12)).foregroundStyle(Theme.mut)
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                Button { Task { await fetch() } } label: {
                    Text("Try again").font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity).padding(12)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card)).foregroundStyle(Theme.txt)
                }
                Button { onLog(r.asMeal); dismiss() } label: {
                    Text("Log it").font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity).padding(12)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Theme.acc)).foregroundStyle(Color(hex: 0x0E0E10))
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.acc.opacity(0.25), lineWidth: 1)))
    }

    private func macro(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.txt)
            Text(k).font(.system(size: 10)).foregroundStyle(Theme.mut)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
    }

    private func fetch() async {
        error = nil; loading = true
        do {
            let r = try await ScanAPI.shared.craving(text, intensity: levels[Int(intensity)], goal: goal, remaining: remaining)
            await MainActor.run { result = r; loading = false }
        } catch {
            await MainActor.run { self.error = "Couldn't get a suggestion — try again."; loading = false }
        }
    }
}
