import Foundation

// MARK: - Shared helpers

/// Calendar-day key used to group diary, water and workout data.
public func dayString(_ date: Date = Date()) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

public enum Meal: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snacks
    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

// MARK: - Nutrition

/// A volume or piece measure for one specific food, e.g. cup = 150 g of
/// cooked rice. Explicit per-food conversions — no density guessing.
public struct ServingUnit: Codable, Hashable {
    public var label: String
    public var grams: Double

    public init(label: String, grams: Double) {
        self.label = label
        self.grams = grams
    }
}

public struct FoodSource: Codable, Hashable {
    public var name: String
    public var license: String

    public init(name: String, license: String) {
        self.name = name
        self.license = license
    }

    public static let usda = FoodSource(
        name: "USDA FoodData Central", license: "Public domain")
    public static let openFoodFacts = FoodSource(
        name: "Open Food Facts", license: "ODbL")
    public static let curated = FoodSource(
        name: "Curated estimate", license: "In-app, unverified")
}

/// All nutrients stored per 100 g. Scaled by grams/100 at log time.
public struct NutrientProfile: Codable, Hashable {
    public var kcal: Double = 0
    public var proteinG: Double = 0
    public var carbsG: Double = 0
    public var fatG: Double = 0
    public var fiberG: Double = 0
    public var sugarG: Double = 0
    public var satFatG: Double = 0
    public var sodiumMg: Double = 0
    public var potassiumMg: Double = 0
    public var calciumMg: Double = 0
    public var ironMg: Double = 0
    public var magnesiumMg: Double = 0
    public var zincMg: Double = 0
    public var vitAMcg: Double = 0
    public var vitCMg: Double = 0
    public var vitDMcg: Double = 0
    public var vitB12Mcg: Double = 0
    public var folateMcg: Double = 0

    public init() {}

    /// Scale a per-100 g profile to an actual portion in grams.
    public func scaled(byGrams grams: Double) -> NutrientProfile {
        let f = grams / 100.0
        var out = NutrientProfile()
        out.kcal = kcal * f
        out.proteinG = proteinG * f
        out.carbsG = carbsG * f
        out.fatG = fatG * f
        out.fiberG = fiberG * f
        out.sugarG = sugarG * f
        out.satFatG = satFatG * f
        out.sodiumMg = sodiumMg * f
        out.potassiumMg = potassiumMg * f
        out.calciumMg = calciumMg * f
        out.ironMg = ironMg * f
        out.magnesiumMg = magnesiumMg * f
        out.zincMg = zincMg * f
        out.vitAMcg = vitAMcg * f
        out.vitCMg = vitCMg * f
        out.vitDMcg = vitDMcg * f
        out.vitB12Mcg = vitB12Mcg * f
        out.folateMcg = folateMcg * f
        return out
    }

    public static func + (l: NutrientProfile, r: NutrientProfile) -> NutrientProfile {
        var out = NutrientProfile()
        out.kcal = l.kcal + r.kcal
        out.proteinG = l.proteinG + r.proteinG
        out.carbsG = l.carbsG + r.carbsG
        out.fatG = l.fatG + r.fatG
        out.fiberG = l.fiberG + r.fiberG
        out.sugarG = l.sugarG + r.sugarG
        out.satFatG = l.satFatG + r.satFatG
        out.sodiumMg = l.sodiumMg + r.sodiumMg
        out.potassiumMg = l.potassiumMg + r.potassiumMg
        out.calciumMg = l.calciumMg + r.calciumMg
        out.ironMg = l.ironMg + r.ironMg
        out.magnesiumMg = l.magnesiumMg + r.magnesiumMg
        out.zincMg = l.zincMg + r.zincMg
        out.vitAMcg = l.vitAMcg + r.vitAMcg
        out.vitCMg = l.vitCMg + r.vitCMg
        out.vitDMcg = l.vitDMcg + r.vitDMcg
        out.vitB12Mcg = l.vitB12Mcg + r.vitB12Mcg
        out.folateMcg = l.folateMcg + r.folateMcg
        return out
    }

    /// Atwater sanity check for seed data: 4/4/9 kcal per g.
    public func atwaterOK(tolerance: Double = 0.15) -> Bool {
        let estimate = 4 * proteinG + 4 * carbsG + 9 * fatG
        guard kcal > 0 else { return estimate == 0 }
        return abs(estimate - kcal) / kcal <= tolerance
    }
}

public struct FoodItem: Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var brand: String?
    public var barcode: String?
    public var servingGrams: Double
    public var servingLabel: String
    public var nutrientsPer100g: NutrientProfile
    public var source: FoodSource
    public var verified: Bool
    public var tags: [String]
    /// Optional volume/piece measures. Nil in old backups decodes as nil.
    public var units: [ServingUnit]?

    public init(id: UUID = UUID(), name: String, brand: String? = nil,
                barcode: String? = nil, servingGrams: Double,
                servingLabel: String, nutrientsPer100g: NutrientProfile,
                source: FoodSource, verified: Bool, tags: [String] = [],
                units: [ServingUnit]? = nil) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.servingGrams = servingGrams
        self.servingLabel = servingLabel
        self.nutrientsPer100g = nutrientsPer100g
        self.source = source
        self.verified = verified
        self.tags = tags
        self.units = units
    }
}

/// Weight-or-volume portion math. "g" always works, "serving" is the
/// food's own serving, anything else must be listed on the food.
public enum PortionMath {
    public static func grams(amount: Double, unit: String,
                             food: FoodItem) -> Double? {
        guard amount > 0 else { return nil }
        if unit == "g" { return amount }
        if unit == "serving" { return amount * food.servingGrams }
        guard let u = food.units?.first(where: { $0.label == unit }) else {
            return nil
        }
        return amount * u.grams
    }

    public static func unitOptions(for food: FoodItem) -> [String] {
        ["g", "serving"] + (food.units?.map(\.label) ?? [])
    }
}

public struct RecipeIngredient: Codable, Hashable {
    public var foodId: UUID
    public var grams: Double
    public init(foodId: UUID, grams: Double) {
        self.foodId = foodId
        self.grams = grams
    }
}

public struct Recipe: Codable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var servings: Double
    public var ingredients: [RecipeIngredient]

    public init(id: UUID = UUID(), name: String, servings: Double,
                ingredients: [RecipeIngredient]) {
        self.id = id
        self.name = name
        self.servings = servings
        self.ingredients = ingredients
    }

    public func nutrientsPerServing(lookup: [UUID: FoodItem]) -> NutrientProfile {
        let total = ingredients.reduce(NutrientProfile()) { acc, ing in
            guard let food = lookup[ing.foodId] else { return acc }
            return acc + food.nutrientsPer100g.scaled(byGrams: ing.grams)
        }
        guard servings > 0 else { return total }
        return total.scaled(byGrams: 100.0 / servings)
    }
}

public struct DiaryEntry: Codable, Hashable, Identifiable {
    public var id: UUID
    public var foodId: UUID?
    public var name: String
    public var grams: Double
    public var meal: Meal
    public var day: String
    public var timestamp: Date
    /// Snapshot at log time: history never shifts with seed updates.
    public var nutrients: NutrientProfile
    /// Set for Apple Health imports ("Apple Health · <app>"), nil when logged here.
    public var source: String?
    /// "hk:<HealthKit UUID>" for imports; dedupe key across syncs.
    public var externalId: String?

    public init(id: UUID = UUID(), foodId: UUID? = nil, name: String,
                grams: Double, meal: Meal, day: String,
                timestamp: Date = Date(), nutrients: NutrientProfile,
                source: String? = nil, externalId: String? = nil) {
        self.id = id
        self.foodId = foodId
        self.name = name
        self.grams = grams
        self.meal = meal
        self.day = day
        self.timestamp = timestamp
        self.nutrients = nutrients
        self.source = source
        self.externalId = externalId
    }
}

public struct WaterIntake: Codable, Hashable {
    public var day: String
    public var ml: Double
    public var source: String?
    /// HealthKit UUIDs already counted in ml, so re-imports never double-add.
    public var externalIds: [String]?
    public init(day: String, ml: Double, source: String? = nil,
                externalIds: [String]? = nil) {
        self.day = day
        self.ml = ml
        self.source = source
        self.externalIds = externalIds
    }
}

public struct WeightEntry: Codable, Hashable, Identifiable {
    public var id: UUID
    public var date: Date
    public var kg: Double
    public var source: String?
    public var externalId: String?
    /// Body-composition companions (e.g. HealthU+ scale cluster).
    public var bodyFatPercent: Double?
    public var leanMassKg: Double?
    public var bmi: Double?
    public init(id: UUID = UUID(), date: Date = Date(), kg: Double,
                source: String? = nil, externalId: String? = nil,
                bodyFatPercent: Double? = nil, leanMassKg: Double? = nil,
                bmi: Double? = nil) {
        self.id = id
        self.date = date
        self.kg = kg
        self.source = source
        self.externalId = externalId
        self.bodyFatPercent = bodyFatPercent
        self.leanMassKg = leanMassKg
        self.bmi = bmi
    }
}
