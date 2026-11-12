import SwiftUI
import HealthifyCore

// MARK: - Recipe builder: name it, add weighed/measured ingredients,
// see per-serving macros + micros live, save once, log forever.

struct DraftIngredient: Hashable {
    var food: FoodItem
    var amount: Double
    var unit: String

    var grams: Double {
        PortionMath.grams(amount: amount, unit: unit, food: food) ?? 0
    }
}

struct RecipeBuilderView: View {
    @EnvironmentObject var store: UserStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var servings = 2.0
    @State private var ingredients: [DraftIngredient] = []
    @State private var showPicker = false

    private var lookup: [UUID: FoodItem] {
        foodLookup(custom: store.customFoods)
    }

    private var perServing: NutrientProfile {
        let total = ingredients.reduce(NutrientProfile()) { acc, d in
            acc + d.food.nutrientsPer100g.scaled(byGrams: d.grams)
        }
        guard servings > 0 else { return total }
        return total.scaled(byGrams: 100.0 / servings)
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !ingredients.isEmpty && servings > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name (required)", text: $name)
                    HStack {
                        Text("Servings")
                        Spacer()
                        TextField("count", value: $servings, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                }
                Section("Ingredients") {
                    ForEach(ingredients, id: \.self) { d in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(d.food.name).font(.subheadline)
                                Text("\(fmt(d.amount)) \(d.unit) = \(fmt(d.grams)) g")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(fmt(d.food.nutrientsPer100g.scaled(byGrams: d.grams).kcal)) kcal")
                                .font(.subheadline).monospacedDigit()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                ingredients.removeAll { $0 == d }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    Button("Add ingredient") { showPicker = true }
                }
                Section("Per serving") {
                    LabeledContent("Energy", value: "\(fmt(perServing.kcal)) kcal")
                    LabeledContent("Protein", value: "\(fmt(perServing.proteinG, 1)) g")
                    LabeledContent("Carbs", value: "\(fmt(perServing.carbsG, 1)) g")
                    LabeledContent("Fat", value: "\(fmt(perServing.fatG, 1)) g")
                }
            }
            .keyboardDoneToolbar()
            .navigationTitle("New recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.success()
                        store.addRecipe(Recipe(
                            name: name.trimmingCharacters(in: .whitespaces),
                            servings: servings,
                            ingredients: ingredients.map {
                                RecipeIngredient(foodId: $0.food.id, grams: $0.grams)
                            }))
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
            .sheet(isPresented: $showPicker) {
                IngredientPickerView { draft in
                    ingredients.append(draft)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Pick one ingredient with its own unit + amount.

struct IngredientPickerView: View {
    @EnvironmentObject var store: UserStore
    @Environment(\.dismiss) private var dismiss
    var onAdd: (DraftIngredient) -> Void

    @State private var query = ""
    @State private var food: FoodItem?
    @State private var amount = 1.0
    @State private var unit = "g"

    private var foods: [FoodItem] { seedFoods + store.customFoods }

    private var matches: [FoodItem] {
        let q = query.lowercased()
        guard !q.isEmpty else { return foods }
        return foods.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if food == nil {
                    Section("Find food") {
                        TextField("Search", text: $query)
                        ForEach(matches.prefix(8)) { f in
                            Button(f.name) {
                                Haptics.tap()
                                food = f
                                unit = f.units?.first?.label ?? "serving"
                            }
                        }
                    }
                } else if let f = food {
                    Section(f.name) {
                        Picker("Unit", selection: $unit) {
                            ForEach(PortionMath.unitOptions(for: f), id: \.self) { u in
                                Text(u).tag(u)
                            }
                        }
                        HStack {
                            Text("Amount")
                            Spacer()
                            TextField("amount", value: $amount, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing).frame(width: 90)
                        }
                        let g = PortionMath.grams(amount: amount, unit: unit, food: f) ?? 0
                        Text("= \(fmt(g)) g · \(fmt(f.nutrientsPer100g.scaled(byGrams: g).kcal)) kcal")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Change food") { food = nil }
                    }
                }
            }
            .keyboardDoneToolbar()
            .navigationTitle("Add ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let f = food else { return }
                        Haptics.success()
                        onAdd(DraftIngredient(food: f, amount: amount, unit: unit))
                        dismiss()
                    }
                    .disabled(food == nil || amount <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Saved recipe: ingredients, per-serving truth, log, delete.

struct RecipeDetailView: View {
    @EnvironmentObject var store: UserStore
    var recipe: Recipe
    var onLog: (Recipe) -> Void
    var onClose: () -> Void

    private var lookup: [UUID: FoodItem] {
        foodLookup(custom: store.customFoods)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Ingredients (\(recipe.ingredients.count))") {
                    ForEach(recipe.ingredients, id: \.foodId) { ing in
                        if let f = lookup[ing.foodId] {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(f.name)
                                    Text("\(fmt(ing.grams)) g")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(fmt(f.nutrientsPer100g.scaled(byGrams: ing.grams).kcal)) kcal")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                let per = recipe.nutrientsPerServing(lookup: lookup)
                Section("Per serving (of \(fmt(recipe.servings, 1)))") {
                    LabeledContent("Energy", value: "\(fmt(per.kcal)) kcal")
                    LabeledContent("Protein", value: "\(fmt(per.proteinG, 1)) g")
                    LabeledContent("Carbs", value: "\(fmt(per.carbsG, 1)) g")
                    LabeledContent("Fat", value: "\(fmt(per.fatG, 1)) g")
                }
                Section {
                    Button("Log this recipe") { onLog(recipe) }
                    if store.recipes.contains(where: { $0.id == recipe.id }) {
                        Button("Delete recipe", role: .destructive) {
                            store.deleteRecipe(recipe)
                            onClose()
                        }
                    }
                }
            }
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onClose() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
