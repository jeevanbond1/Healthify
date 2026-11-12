import SwiftUI
import HealthifyCore

// MARK: - Log sheet: pick grams, see totals live, commit. Symmetric with edit.

struct LogEntrySheet: View {
    @EnvironmentObject var store: UserStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var pick: FoodPick
    var meal: Meal
    var day: String

    init(pick: FoodPick, day: String, meal: Meal = .snacks) {
        _pick = State(initialValue: pick)
        self.day = day
        self.meal = meal
    }

    init(meal: Meal, day: String) {
        // Diary "Log" entry point: search defaults to the full list.
        _pick = State(initialValue: .food(seedFoods[0]))
        self.day = day
        self.meal = meal
        _searchFirst = State(initialValue: true)
    }

    @State private var searchFirst = false
    @State private var query = ""
    @State private var amount = 0.0
    @State private var unit = "g"
    @State private var mealSel: Meal = .snacks
    @State private var showDetail = false

    /// Resolved grams for food picks; for recipes the amount IS servings.
    private var grams: Double {
        if case .food(let f) = pick {
            return PortionMath.grams(amount: amount, unit: unit, food: f) ?? 0
        }
        return amount
    }

    private var foods: [FoodItem] {
        seedFoods + store.customFoods
    }

    private var currentFood: FoodItem? {
        if case .food(let f) = pick { return f }
        return nil
    }

    private var nutrients: NutrientProfile {
        switch pick {
        case .food(let f):
            return f.nutrientsPer100g.scaled(byGrams: grams)
        case .recipe(let r):
            // grams doubles as servings here; per-serving × servings.
            let per = r.nutrientsPerServing(lookup: foodLookup(custom: store.customFoods))
            return per.scaled(byGrams: grams * 100)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if searchFirst {
                    Section("Find food") {
                        TextField("Search", text: $query)
                        ForEach(matchingFoods.prefix(8)) { f in
                            Button(f.name) {
                                pickFood(f)
                            }
                        }
                    }
                }
                Section("Portion") {
                    Picker("Meal", selection: $mealSel) {
                        ForEach(Meal.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    if let f = currentFood {
                        Picker("Unit", selection: $unit) {
                            ForEach(PortionMath.unitOptions(for: f), id: \.self) { u in
                                Text(u == "serving" ? "serving (\(f.servingLabel))" : u).tag(u)
                            }
                        }
                        HStack {
                            Text(unit == "g" ? "Weight" : "Quantity")
                            Spacer()
                            Button { amount = max(0, amount - 1) } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            TextField("amount", value: $amount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Button { amount += 1 } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                        Text(unit == "g" ? "= \(fmt(grams)) g"
                             : "\(fmt(amount)) × \(unit) = \(fmt(grams)) g")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("Servings")
                            Spacer()
                            TextField("serv", value: $amount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                        }
                    }
                }
                Section("Totals") {
                    LabeledContent("Energy", value: "\(fmt(nutrients.kcal)) kcal")
                    LabeledContent("Protein", value: "\(fmt(nutrients.proteinG, 1)) g")
                    LabeledContent("Carbs", value: "\(fmt(nutrients.carbsG, 1)) g")
                    LabeledContent("Fat", value: "\(fmt(nutrients.fatG, 1)) g")
                }
            }
            .keyboardDoneToolbar()
            .navigationTitle(pickTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        Haptics.success()
                        commit()
                        dismiss()
                    }
                    .disabled(grams <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            mealSel = meal
            if case .food(let f) = pick {
                amount = 1
                unit = f.units?.first?.label ?? "serving"
            }
            if case .recipe = pick { amount = 1 }
        }
    }

    private var matchingFoods: [FoodItem] {
        let q = query.lowercased()
        guard !q.isEmpty else { return foods }
        return foods.filter { $0.name.lowercased().contains(q) }
    }

    private var pickTitle: String {
        switch pick {
        case .food(let f): return f.name
        case .recipe(let r): return r.name
        }
    }

    private func pickFood(_ f: FoodItem) {
        pick = .food(f)
        amount = 1
        unit = f.units?.first?.label ?? "serving"
        searchFirst = false
        Haptics.tap()
    }

    private func commit() {
        let name: String
        let fid: UUID?
        switch pick {
        case .food(let f): name = f.name; fid = f.id
        case .recipe(let r): name = r.name; fid = nil
        }
        store.logEntry(DiaryEntry(foodId: fid, name: name, grams: grams,
                                 meal: mealSel, day: day, nutrients: nutrients))
    }
}
