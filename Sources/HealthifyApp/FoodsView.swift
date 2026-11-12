import SwiftUI
import HealthifyCore

// MARK: - Foods: search, detail, custom foods, barcode. Miss path never dead-ends.

enum FoodPick: Hashable, Identifiable {
    case food(FoodItem)
    case recipe(Recipe)

    var id: String {
        switch self {
        case .food(let f): return "food-\(f.id)"
        case .recipe(let r): return "recipe-\(r.id)"
        }
    }
}

struct FoodsView: View {
    @EnvironmentObject var store: UserStore
    @State private var query = ""
    @State private var picked: FoodPick?
    @State private var showCustom = false
    @State private var showRecipeBuilder = false
    @State private var detailRecipe: Recipe?
    @State private var barcode = ""
    @State private var showScanner = false
    @State private var barcodeMessage: String?
    @State private var pendingBarcode: String?
    @State private var scannedCode: String?

    private var allFoods: [FoodItem] { seedFoods + store.customFoods }

    private var results: [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allFoods }
        // Prefix matches first, then substring: predictable ranking, no index needed.
        let pre = allFoods.filter { $0.name.lowercased().hasPrefix(q) }
        let sub = allFoods.filter {
            !pre.map(\.id).contains($0.id)
                && $0.name.lowercased().contains(q)
        }
        return pre + sub
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Enter barcode", text: $barcode)
                            .keyboardType(.numberPad)
                        Button("Find") { lookupBarcode(barcode) }
                        Button("Scan") { showScanner = true }
                    }
                    if let msg = barcodeMessage {
                        Text(msg).font(.caption).foregroundStyle(.secondary)
                        if pendingBarcode != nil {
                            Button("Create this food") {
                                showCustom = true
                            }
                            .font(.caption)
                        }
                    }
                } header: { Text("Barcode") }

                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    let recents = RecentFoods.recentFoodIds(in: store.diary)
                        .compactMap { id in allFoods.first { $0.id == id } }
                    if !recents.isEmpty {
                        Section {
                            ForEach(recents) { food in
                                Button {
                                    Haptics.tap()
                                    picked = .food(food)
                                } label: { FoodRow(food: food) }
                            }
                        } header: { Text("Recent") }
                    }
                }
                Section {
                    if results.isEmpty {
                        Text("No match in the dictionary.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Add this food") { showCustom = true }
                        Button("Create a recipe instead") { showRecipeBuilder = true }
                    }
                    ForEach(results) { food in
                        Button {
                            Haptics.tap()
                            picked = .food(food)
                        } label: {
                            FoodRow(food: food)
                        }
                    }
                } header: { Text("Foods") }
                Section {
                    ForEach(seedRecipes()) { recipe in
                        Button {
                            Haptics.tap()
                            detailRecipe = recipe
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(recipe.name).foregroundStyle(.primary)
                                    Text("Starter recipe · \(recipe.ingredients.count) ingredients")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: { Text("Starter recipes") }
                Section {
                    ForEach(store.recipes) { recipe in
                        Button {
                            Haptics.tap()
                            detailRecipe = recipe
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(recipe.name).foregroundStyle(.primary)
                                    Text("\(recipe.ingredients.count) ingredients · \(fmt(recipe.servings, 0)) servings")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button {
                        showRecipeBuilder = true
                    } label: {
                        Label("New recipe", systemImage: "plus.circle")
                    }
                } header: { Text("My recipes") }
            }
            .searchable(text: $query, prompt: "Search foods")
            .keyboardDoneToolbar()
            .navigationTitle("Foods")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCustom = true
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $picked) { pick in
                LogEntrySheet(pick: pick, day: dayString())
            }
            .sheet(isPresented: $showCustom) {
                CustomFoodForm(prefillBarcode: pendingBarcode)
            }
            .sheet(isPresented: $showRecipeBuilder) {
                RecipeBuilderView()
            }
            .sheet(item: $detailRecipe) { recipe in
                RecipeDetailView(recipe: recipe, onLog: { r in
                    // Dismiss first, present the log sheet on the next
                    // runloop — never stacked on the detail sheet.
                    detailRecipe = nil
                    DispatchQueue.main.async { picked = .recipe(r) }
                }, onClose: { detailRecipe = nil })
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { code in
                    barcode = code
                    // Stash only: the detail sheet presents after the
                    // scanner dismisses, never stacked on top of it.
                    scannedCode = code
                }
            }
            .onChange(of: showScanner) { _, isPresented in
                if !isPresented, let code = scannedCode {
                    scannedCode = nil
                    lookupBarcode(code)
                }
            }
        }
    }

    private func lookupBarcode(_ code: String) {
        let c = code.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return }
        if let food = allFoods.first(where: { $0.barcode == c }) {
            barcodeMessage = nil
            pendingBarcode = nil
            picked = .food(food)
        } else {
            pendingBarcode = c
            barcodeMessage = "No match for \(c). Create it — "
                + "it saves to your foods and backup."
            Haptics.error()
        }
    }
}

struct FoodRow: View {
    var food: FoodItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).foregroundStyle(.primary)
                Text("\(fmt(food.nutrientsPer100g.kcal)) kcal / 100 g · "
                    + "\(food.source.name)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            SourceBadge(food: food)
        }
    }
}

/// Trust at a glance: verified lab-grade source vs user-facing estimate.
struct SourceBadge: View {
    var food: FoodItem

    var body: some View {
        Label(food.verified ? "Verified" : "Estimate",
              systemImage: food.verified ? "checkmark.seal.fill" : "pencil.line")
            .font(.caption2)
            .foregroundStyle(food.verified ? .green : .orange)
    }
}
