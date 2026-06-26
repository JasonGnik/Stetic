import SwiftUI

// Cal AI-style meal scan: scan the photo, then an editable results card —
// total calories + macros, a servings stepper, and an ingredient list you can
// add to / remove / edit. Totals recompute live from the items.
struct MealScanView: View {
    let image: UIImage
    let dataB64: String
    var mealType: String = MealType.current().rawValue
    var scanMode: String = "meal"   // "meal" (plate) or "label" (nutrition facts)
    var onLogged: () -> Void
    var preset: MealEstimate? = nil   // DEBUG: skip the network and show a sample result
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .scanning
    @State private var est = MealEstimate(name: "Meal", calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0, confidence: "")
    @State private var saving = false
    @State private var savedMeal = false
    @State private var editTarget: EditTarget?
    @State private var showSearch = false
    @State private var startedAt = Date()
    private let scanDuration: TimeInterval = 2.8   // shared with run() so the bar lands as results appear
    enum Phase { case scanning, results }
    struct EditTarget: Identifiable { let id = UUID(); var index: Int? }   // nil = new item

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if phase == .scanning { scanningView } else { resultsView }
        }
        .task { await run() }
        .sheet(item: $editTarget) { target in itemEditor(target) }
        .sheet(isPresented: $showSearch) {
            FoodSearchView(onPick: { hit in est.items.append(hit.asItem) },
                           onManual: { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { editTarget = EditTarget(index: nil) } })
        }
    }

    // The analysis steps the scanner appears to walk through.
    private let scanSteps = ["Detecting foods", "Estimating portions", "Calculating macros", "Finishing up"]
    // Where the pulsing "detection" nodes sit (fractions of the frame).
    private let nodes: [CGPoint] = [.init(x: 0.32, y: 0.40), .init(x: 0.62, y: 0.34),
                                    .init(x: 0.50, y: 0.58), .init(x: 0.72, y: 0.62), .init(x: 0.38, y: 0.68)]

    // MARK: scanning (loading) — photo + an AI vision sweep + a climbing progress bar.
    private var scanningView: some View {
        VStack(spacing: 0) {
            header("Scanning meal")
            Spacer(minLength: 8)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: w, height: h).clipped()
                    Rectangle().fill(Color.black.opacity(0.22))
                    scanGrid(w: w, h: h)
                    cornerBrackets(w: w, h: h)
                    TimelineView(.animation) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        let sweep = (t.truncatingRemainder(dividingBy: 1.8)) / 1.8   // 0→1 sweep, top→bottom
                        let y = sweep * h
                        ZStack {
                            // bright sweeping band + crisp line
                            Rectangle().fill(LinearGradient(colors: [.clear, Theme.acc.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom))
                                .frame(height: 120).position(x: w / 2, y: y)
                            Rectangle().fill(Theme.acc).frame(height: 2.5)
                                .shadow(color: Theme.acc, radius: 12).position(x: w / 2, y: y)
                            ForEach(nodes.indices, id: \.self) { idx in
                                let nx = nodes[idx].x * w, ny = nodes[idx].y * h
                                detectionNode(active: abs(ny - y) < 70).position(x: nx, y: ny)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .frame(height: 300).padding(.horizontal, 18)

            // Big, unmistakable loading block: title + climbing bar + current step.
            TimelineView(.animation) { tl in
                let elapsed = tl.date.timeIntervalSince(startedAt)
                let frac = min(0.97, max(0.04, elapsed / scanDuration))
                let step = scanSteps[min(scanSteps.count - 1, Int(frac * Double(scanSteps.count)))]
                VStack(spacing: 12) {
                    Text("Analyzing your meal").font(.system(size: 19, weight: .heavy)).foregroundStyle(Theme.txt)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line)
                            Capsule().fill(LinearGradient(colors: [Theme.acc.opacity(0.7), Theme.acc], startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * frac)
                                .shadow(color: Theme.acc.opacity(0.5), radius: 6)
                        }
                    }
                    .frame(height: 8)
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(Theme.acc)
                        Text(step + "…").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.mut)
                            .contentTransition(.opacity)
                        Spacer()
                        Text("\(Int(frac * 100))%").font(.system(size: 13.5, weight: .heavy)).foregroundStyle(Theme.acc)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 22).padding(.top, 22)
            }
            Spacer()
        }
    }

    // Faint targeting grid behind the sweep, for a "vision system" feel.
    private func scanGrid(w: CGFloat, h: CGFloat) -> some View {
        Path { p in
            let step: CGFloat = 44
            var x: CGFloat = 0; while x < w { p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: h)); x += step }
            var y: CGFloat = 0; while y < h { p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: w, y: y)); y += step }
        }.stroke(Theme.acc.opacity(0.10), lineWidth: 0.5)
    }

    private func detectionNode(active: Bool) -> some View {
        ZStack {
            Circle().stroke(Theme.acc.opacity(active ? 0.9 : 0.0), lineWidth: 1.5).frame(width: 26, height: 26)
            Circle().fill(Theme.acc.opacity(active ? 0.9 : 0.0)).frame(width: 5, height: 5)
        }
        .scaleEffect(active ? 1 : 0.5)
        .animation(.easeOut(duration: 0.35), value: active)
    }

    // MARK: results (editable) — Cal AI style
    private var resultsView: some View {
        VStack(spacing: 0) {
            header("Nutrition")
            ScrollView {
                VStack(spacing: 14) {
                    // The photo is only used during the scan — it's never shown here or stored.
                    // name + servings stepper
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(est.name).font(.system(size: 19, weight: .heavy)).foregroundStyle(Theme.txt)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Servings").font(.system(size: 12)).foregroundStyle(Theme.mut)
                        }
                        Spacer()
                        stepper
                    }

                    // big calories card
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill").font(.system(size: 22)).foregroundStyle(Theme.acc)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Calories").font(.system(size: 12)).foregroundStyle(Theme.mut)
                            Text("\(Int(est.shownCalories))").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.txt)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1)))

                    HStack(spacing: 10) {
                        macroChip("Protein", est.shownProtein, "bolt.fill")
                        macroChip("Carbs", est.shownCarbs, "leaf.fill")
                        macroChip("Fats", est.shownFat, "drop.fill")
                    }

                    // ingredients
                    HStack {
                        Text("Ingredients").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                        Spacer()
                        Button { showSearch = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                                Text("Add more").font(.system(size: 13, weight: .semibold))
                            }.foregroundStyle(Theme.acc)
                        }
                    }
                    .padding(.top, 4)

                    if est.items.isEmpty {
                        Text(est.note ?? "No ingredients yet — add your foods.")
                            .font(.system(size: 13)).foregroundStyle(Theme.mut)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(est.items.enumerated()), id: \.element.id) { idx, item in
                            ingredientRow(item, idx)
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            controls
        }
    }

    private var stepper: some View {
        HStack(spacing: 14) {
            Button { if est.servings > 1 { est.servings -= 1 } } label: {
                Image(systemName: "minus").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                    .frame(width: 30, height: 30).background(Circle().fill(Theme.card))
            }
            Text("\(Int(est.servings))").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt).frame(minWidth: 16)
            Button { est.servings += 1 } label: {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: 0x0E0E10))
                    .frame(width: 30, height: 30).background(Circle().fill(Theme.acc))
            }
        }
    }

    private func macroChip(_ label: String, _ value: Double, _ icon: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11)).foregroundStyle(Theme.acc)
                Text(label).font(.system(size: 11)).foregroundStyle(Theme.mut)
            }
            Text("\(Int(value))g").font(.system(size: 17, weight: .heavy)).foregroundStyle(Theme.txt)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1)))
    }

    private func ingredientRow(_ item: MealEstimate.Item, _ idx: Int) -> some View {
        Button { editTarget = EditTarget(index: idx) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt)
                    if let p = item.portion, !p.isEmpty {
                        Text(p).font(.system(size: 12)).foregroundStyle(Theme.mut)
                    }
                }
                Spacer()
                Text("\(Int(item.calories)) cal").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.mut)
                Button { est.items.remove(at: idx) } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
                        .frame(width: 26, height: 26).background(Circle().fill(Theme.card))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 10).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var controls: some View {
        HStack(spacing: 10) {
            Button { Task { await saveMeal() } } label: {
                Image(systemName: savedMeal ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(savedMeal ? Color(hex: 0x0E0E10) : Theme.txt)
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 12).fill(savedMeal ? Theme.acc : Theme.card))
            }
            .disabled(savedMeal || est.shownCalories <= 0)
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
                .background(RoundedRectangle(cornerRadius: 12).fill(est.shownCalories > 0 ? Theme.acc : Theme.line))
                .foregroundStyle(est.shownCalories > 0 ? Color(hex: 0x0E0E10) : Theme.mut)
            }
            .disabled(saving || est.shownCalories <= 0)
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 14)
    }

    // MARK: add / edit an ingredient
    private func itemEditor(_ target: EditTarget) -> some View {
        ItemEditor(item: target.index.map { est.items[$0] }) { result in
            if let i = target.index { est.items[i] = result } else { est.items.append(result) }
            editTarget = nil
        } onCancel: { editTarget = nil }
        .presentationDetents([.height(440)])
    }

    private func header(_ title: String) -> some View {
        HStack {
            Text(title).font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut)
                    .padding(8).background(Circle().fill(Theme.card))
            }
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 12)
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

    // MARK: flow
    private func run() async {
        if let preset { est = preset; withAnimation { phase = .results }; return }
        let start = Date()
        await MainActor.run { startedAt = start }
        let minScanTime = scanDuration   // always let the scan animation play through

        var result = try? await scanOnce()
        // The same plate occasionally comes back empty — retry once before falling back.
        if isEmpty(result) { result = try? await scanOnce() }

        // Keep the animation on screen for at least minScanTime so it never just flashes.
        let elapsed = Date().timeIntervalSince(start)
        if elapsed < minScanTime {
            try? await Task.sleep(nanoseconds: UInt64((minScanTime - elapsed) * 1_000_000_000))
        }
        await MainActor.run {
            if let result, !isEmpty(result) {
                est = result
            } else {
                est.note = "Add your foods below to log this meal."
            }
            withAnimation(.easeOut(duration: 0.3)) { phase = .results }
        }
    }

    private func scanOnce() async throws -> MealEstimate {
        try await ScanAPI.shared.scanMeal(.init(mimeType: "image/jpeg", dataB64: dataB64), mode: scanMode)
    }
    private func isEmpty(_ e: MealEstimate?) -> Bool {
        guard let e else { return true }
        return e.items.isEmpty && e.baseCalories <= 0
    }

    private func add() async {
        saving = true
        try? await ScanAPI.shared.logMeal(est, mealType: mealType)
        await MainActor.run { saving = false; onLogged(); dismiss() }
    }

    private func saveMeal() async {
        try? await ScanAPI.shared.saveMeal(est)
        await MainActor.run { withAnimation { savedMeal = true } }
    }
}

// A small add/edit form for one ingredient.
private struct ItemEditor: View {
    let item: MealEstimate.Item?
    var onSave: (MealEstimate.Item) -> Void
    var onCancel: () -> Void

    @State private var name = ""
    @State private var portion = ""
    @State private var cals = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(item == nil ? "Add food" : "Edit food").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.txt)
                Spacer()
                Button { onCancel() } label: { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.mut) }
            }
            field("Food name", $name)
            field("Portion (e.g. 1 cup)", $portion)
            HStack(spacing: 8) { numField("Calories", $cals); numField("Protein", $protein) }
            HStack(spacing: 8) { numField("Carbs", $carbs); numField("Fat", $fat) }
            Button {
                var it = item ?? MealEstimate.Item(name: "")
                it.name = name.isEmpty ? "Food" : name
                it.portion = portion.isEmpty ? nil : portion
                it.calories = Double(cals) ?? 0
                it.protein_g = Double(protein) ?? 0
                it.carbs_g = Double(carbs) ?? 0
                it.fat_g = Double(fat) ?? 0
                onSave(it)
            } label: {
                Text("Save").font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill((Double(cals) ?? 0) > 0 ? Theme.acc : Theme.line))
                    .foregroundStyle((Double(cals) ?? 0) > 0 ? Color(hex: 0x0E0E10) : Theme.mut)
            }
            .disabled((Double(cals) ?? 0) <= 0)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 18)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            if let item {
                name = item.name; portion = item.portion ?? ""
                cals = item.calories > 0 ? "\(Int(item.calories))" : ""
                protein = item.protein_g > 0 ? "\(Int(item.protein_g))" : ""
                carbs = item.carbs_g > 0 ? "\(Int(item.carbs_g))" : ""
                fat = item.fat_g > 0 ? "\(Int(item.fat_g))" : ""
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(label).foregroundStyle(Theme.mut))
            .font(.system(size: 15)).foregroundStyle(Theme.txt).padding(13)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.line, lineWidth: 1)))
    }
    private func numField(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
            TextField("0", text: text).keyboardType(.numberPad)
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.txt).padding(11)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1)))
        }
    }
}
