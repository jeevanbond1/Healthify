import SwiftUI
import HealthifyCore

// MARK: - Custom food: required per-100 g macros before save (inline validation).

struct CustomFoodForm: View {
    @EnvironmentObject var store: UserStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var barcode: String?
    @State private var servingGrams = 100.0
    @State private var servingLabel = "1 serving (100 g)"
    @State private var kcal = 0.0
    @State private var protein = 0.0
    @State private var carbs = 0.0
    @State private var fat = 0.0
    @State private var fiber = 0.0
    @State private var showMicros = false

    init(prefillBarcode: String? = nil) {
        _barcode = State(initialValue: prefillBarcode)
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && servingGrams > 0 && kcal >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name (required)", text: $name)
                    HStack {
                        Text("Serving size (g)")
                        Spacer()
                        TextField("g", value: $servingGrams, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(width: 90)
                    }
                    TextField("Serving label", text: $servingLabel)
                    if let code = barcode {
                        LabeledContent("Barcode", value: code)
                    }
                }
                Section("Per 100 g (required)") {
                    macroField("Energy (kcal)", $kcal)
                    macroField("Protein (g)", $protein)
                    macroField("Carbs (g)", $carbs)
                    macroField("Fat (g)", $fat)
                }
                Section {
                    Toggle("More nutrients", isOn: $showMicros)
                    if showMicros {
                        macroField("Fibre (g)", $fiber)
                    }
                }
            }
            .navigationTitle("New food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.success()
                        save()
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func macroField(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).frame(width: 90)
        }
    }

    private func save() {
        var n = NutrientProfile()
        n.kcal = kcal; n.proteinG = protein
        n.carbsG = carbs; n.fatG = fat; n.fiberG = fiber
        store.addCustomFood(FoodItem(
            name: name.trimmingCharacters(in: .whitespaces),
            barcode: barcode, servingGrams: servingGrams,
            servingLabel: servingLabel, nutrientsPer100g: n,
            source: .init(name: "Your entry", license: "On this phone"),
            verified: false, tags: ["custom"]))
    }
}
