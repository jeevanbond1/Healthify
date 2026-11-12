import SwiftUI
import HealthifyCore

// MARK: - Diary: today at a glance, then meals. No dead ends.

struct DiaryView: View {
    @EnvironmentObject var store: UserStore
    @State private var day = dayString()
    @State private var addSheet: Meal?
    @State private var editEntry: DiaryEntry?
    @State private var waterDraft = 250.0

    private var totals: NutrientProfile { store.totals(on: day) }
    private var goal: GoalProfile { store.goal }

    private func shiftDay(_ by: Int) {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: day),
              let next = Calendar.current.date(byAdding: .day, value: by, to: d) else { return }
        day = dayString(next)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack {
                        Button { shiftDay(-1) } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(day == dayString() ? "Today" : day)
                            .font(.headline)
                        if day != dayString() {
                            Button("Today") { day = dayString() }
                                .font(.caption.bold())
                        }
                        Spacer()
                        Button { shiftDay(1) } label: { Image(systemName: "chevron.right") }
                    }
                    .padding(.horizontal, 4)
                    GlassCard {
                        HStack(spacing: 14) {
                            RingView(
                                progress: totals.kcal / max(goal.targetKcal, 1),
                                size: 92,
                                center: fmt(totals.kcal),
                                caption: "of \(fmt(goal.targetKcal))")
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Remaining \(fmt(goal.targetKcal - totals.kcal)) kcal")
                                    .font(.title3.bold()).monospacedDigit()
                                MacroBar(label: "Protein", grams: totals.proteinG,
                                         target: goal.proteinG)
                                MacroBar(label: "Carbs", grams: totals.carbsG,
                                         target: goal.carbsG)
                                MacroBar(label: "Fat", grams: totals.fatG,
                                         target: goal.fatG)
                                HStack(spacing: 8) {
                                    Text("Water \(fmt(store.waterMl(on: day), 0)) ml")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Button("+\(fmt(waterDraft, 0))") {
                                        Haptics.tap()
                                        store.addWater(ml: waterDraft, day: day)
                                    }
                                    .font(.caption.bold())
                                    Stepper("", value: $waterDraft, in: 50...1000, step: 50)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Meal.allCases) { meal in
                                mealTimeline(meal)
                                if meal != Meal.allCases.last { Divider().padding(.vertical, 8) }
                            }
                        }
                    }
                    microsCard
                }
                .padding()
            }
            .keyboardDoneToolbar()
            .navigationTitle("Daily log")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Log") { addSheet = .snacks }
                }
            }
            .sheet(item: $addSheet) { meal in
                LogEntrySheet(meal: meal, day: day)
            }
            .sheet(item: $editEntry) { entry in
                EditEntrySheet(entry: entry)
            }
        }
    }

    private func mealTimeline(_ meal: Meal) -> some View {
        let items = store.entries(on: day, meal: meal)
        return VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(meal.label).font(.headline)
                    Spacer()
                    Text("\(fmt(items.reduce(0) { $0 + $1.nutrients.kcal })) kcal")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .monospacedDigit()
                    Button {
                        Haptics.tap()
                        addSheet = meal
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                if items.isEmpty {
                    Text("Nothing logged yet — tap + to add")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(items) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.name).font(.subheadline)
                            Text("\(fmt(entry.grams)) g")
                                .font(.caption).foregroundStyle(.secondary)
                            if let src = entry.source {
                                Text(src).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if entry.grams > 0 {
                            Button {
                                store.adjustEntry(entry: entry,
                                                  toGrams: max(10, entry.grams - stepGrams(entry)))
                            } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain)
                            Button {
                                store.adjustEntry(entry: entry,
                                                  toGrams: entry.grams + stepGrams(entry))
                            } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.plain)
                        }
                        Text("\(fmt(entry.nutrients.kcal)) kcal")
                            .font(.subheadline).monospacedDigit()
                        Button { editEntry = entry } label: {
                            Image(systemName: "pencil").font(.callout)
                        }
                        .buttonStyle(.plain)
                        Button(role: .destructive) {
                            store.deleteEntry(entry)
                        } label: {
                            Image(systemName: "trash")
                                .font(.callout)
                        }
                    }
                }
        }
    }

    private var microsCard: some View {
        GlassCard {
            DisclosureGroup("Micronutrients") {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 8) {
                    ForEach(DailyReference.micros) { micro in
                        let v = micro.get(totals)
                        VStack(alignment: .leading) {
                            Text("\(micro.label) \(fmt(v, 1))\(micro.unit)")
                                .font(.caption).monospacedDigit()
                            GeometryReader { geo in
                                Capsule().fill(.quaternary)
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(Color.accentColor.opacity(0.7))
                                            .frame(width: geo.size.width
                                                * min(v / micro.daily, 1))
                                    }
                            }
                            .frame(height: 4)
                        }
                    }
                }
                Text("Reference intakes shown for guidance only, not diagnosis.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            }
        }
    }

    /// Inline +/- step: one serving when the food is known, else 10 g.
    private func stepGrams(_ entry: DiaryEntry) -> Double {
        guard let fid = entry.foodId,
              let food = foodLookup(custom: store.customFoods)[fid] else { return 10 }
        return food.servingGrams
    }
}

// MARK: - Edit a logged entry: quantity or weight, meal, save.

struct EditEntrySheet: View {
    @EnvironmentObject var store: UserStore
    @Environment(\.dismiss) private var dismiss
    var entry: DiaryEntry
    @State private var amount: Double = 0
    @State private var unit = "g"
    @State private var mealSel: Meal = .snacks

    private var food: FoodItem? {
        entry.foodId.flatMap { foodLookup(custom: store.customFoods)[$0] }
    }
    private var grams: Double {
        if let f = food {
            return PortionMath.grams(amount: amount, unit: unit, food: f) ?? 0
        }
        return amount
    }
    private var nutrients: NutrientProfile {
        if let f = food { return f.nutrientsPer100g.scaled(byGrams: grams) }
        guard entry.grams > 0 else { return entry.nutrients }
        return entry.nutrients.scaled(byGrams: grams / entry.grams * 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(entry.name) {
                    Picker("Meal", selection: $mealSel) {
                        ForEach(Meal.allCases) { m in Text(m.label).tag(m) }
                    }
                    if let f = food {
                        Picker("Unit", selection: $unit) {
                            ForEach(PortionMath.unitOptions(for: f), id: \.self) { u in
                                Text(u == "serving" ? "serving (\(f.servingLabel))" : u).tag(u)
                            }
                        }
                    }
                    HStack {
                        Text(food != nil && unit != "g" ? "Quantity" : "Weight (g)")
                        Spacer()
                        Button { amount = max(0, amount - 1) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain)
                        TextField("amount", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 70)
                        Button { amount += 1 } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.plain)
                    }
                    Text("= \(fmt(grams)) g · \(fmt(nutrients.kcal)) kcal")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Delete entry", role: .destructive) {
                        store.deleteEntry(entry); dismiss()
                    }
                }
            }
            .keyboardDoneToolbar()
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var e = entry
                        e.grams = grams; e.meal = mealSel; e.nutrients = nutrients
                        store.updateEntry(e)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(grams <= 0)
                }
            }
            .onAppear {
                mealSel = entry.meal
                if let f = food {
                    unit = "g"; amount = entry.grams
                } else { amount = entry.grams }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
