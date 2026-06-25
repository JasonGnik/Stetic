import SwiftUI

// Cal AI-style meal scan: scan the photo, then an editable results card —
// total calories + macros, a servings stepper, and an ingredient list you can
// add to / remove / edit. Totals recompute live from the items.
struct MealScanView: View {
    let image: UIImage
    let dataB64: String
    var onLogged: () -> Void
    var preset: MealEstimate? = nil   // DEBUG: skip the network and show a sample result
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .scanning
    @State private var est = MealEstimate(name: "Meal", calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0, confidence: "")
    @State private var saving = false
    @State private var editTarget: EditTarget?
    enum Phase { case scanning, results }
    struct EditTarget: Identifiable { let id = UUID(); var index: Int? }   // nil = new item

    var body: some View {
        Group {
            if phase == .scanning { scanningView } else { resultsView }
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await run() }
        .sheet(item: $editTarget) { target in itemEditor(target) }
    }

    // MARK: scanning (loading) — photo + sweeping scan line, no error mid-scan
    private var scanningView: some View {
        VStack(spacing: 0) {
            header("Scanning meal")
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: w, height: h).clipped()
                    Rectangle().fill(Color.black.opacity(0.28))
                    cornerBrackets(w: w, h: h)
                    TimelineView(.animation) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        let y = (sin(t * 1.6) * 0.5 + 0.5) * h
                        ZStack {
                            Rectangle().fill(LinearGradient(colors: [.clear, Theme.acc.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom))
                                .frame(height: 60).position(x: w / 2, y: y)
                            Rectangle().fill(Theme.acc).frame(height: 2).shadow(color: Theme.acc, radius: 6).position(x: w / 2, y: y)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .frame(height: 380).padding(.horizontal, 18)
            Text("Identifying foods…").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.mut).padding(.top, 16)
            Spacer()
        }
    }

    // MARK: results (editable) — Cal AI style
    private var resultsView: some View {
        VStack(spacing: 0) {
            header("Nutrition")
            ScrollView {
                VStack(spacing: 14) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(height: 180).frame(maxWidth: .infinity).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))

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
                        Button { editTarget = EditTarget(index: nil) } label: {
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
        do {
            let result = try await ScanAPI.shared.scanMeal(.init(mimeType: "image/jpeg", dataB64: dataB64))
            await MainActor.run {
                est = result
                if est.items.isEmpty && est.baseCalories <= 0 {
                    est.note = "Couldn't read it automatically — add your foods below."
                }
                withAnimation(.easeOut(duration: 0.3)) { phase = .results }
            }
        } catch {
            await MainActor.run {
                est.note = "Couldn't read it automatically — add your foods below."
                withAnimation { phase = .results }
            }
        }
    }

    private func add() async {
        saving = true
        try? await ScanAPI.shared.logMeal(est)
        await MainActor.run { saving = false; onLogged(); dismiss() }
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
