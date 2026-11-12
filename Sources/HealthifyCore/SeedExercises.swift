import Foundation

public let seedExercises: [Exercise] = [
    Exercise(name: "Bench press", muscleGroup: "Chest",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Push-up", muscleGroup: "Chest",
             equipment: "Bodyweight", kind: .bodyweight),
    Exercise(name: "Squat", muscleGroup: "Legs",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Leg press", muscleGroup: "Legs",
             equipment: "Machine", kind: .weighted),
    Exercise(name: "Deadlift", muscleGroup: "Back",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Barbell row", muscleGroup: "Back",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Pull-up", muscleGroup: "Back",
             equipment: "Bodyweight", kind: .bodyweight),
    Exercise(name: "Overhead press", muscleGroup: "Shoulders",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Biceps curl", muscleGroup: "Arms",
             equipment: "Dumbbell", kind: .weighted),
    Exercise(name: "Triceps pushdown", muscleGroup: "Arms",
             equipment: "Cable", kind: .weighted),
    Exercise(name: "Plank", muscleGroup: "Core",
             equipment: "Bodyweight", kind: .timed),
    Exercise(name: "Running", muscleGroup: "Cardio",
             equipment: "Treadmill", kind: .cardio),
    Exercise(name: "Incline bench press", muscleGroup: "Chest",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Chest fly", muscleGroup: "Chest",
             equipment: "Cable", kind: .weighted),
    Exercise(name: "Lat pulldown", muscleGroup: "Back",
             equipment: "Cable", kind: .weighted),
    Exercise(name: "Seated cable row", muscleGroup: "Back",
             equipment: "Cable", kind: .weighted),
    Exercise(name: "Face pull", muscleGroup: "Shoulders",
             equipment: "Cable", kind: .weighted),
    Exercise(name: "Lateral raise", muscleGroup: "Shoulders",
             equipment: "Dumbbell", kind: .weighted),
    Exercise(name: "Shrug", muscleGroup: "Shoulders",
             equipment: "Dumbbell", kind: .weighted),
    Exercise(name: "Hammer curl", muscleGroup: "Arms",
             equipment: "Dumbbell", kind: .weighted),
    Exercise(name: "Preacher curl", muscleGroup: "Arms",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Skull crusher", muscleGroup: "Arms",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Dips", muscleGroup: "Arms",
             equipment: "Bodyweight", kind: .bodyweight),
    Exercise(name: "Romanian deadlift", muscleGroup: "Legs",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Leg extension", muscleGroup: "Legs",
             equipment: "Machine", kind: .weighted),
    Exercise(name: "Leg curl", muscleGroup: "Legs",
             equipment: "Machine", kind: .weighted),
    Exercise(name: "Calf raise", muscleGroup: "Legs",
             equipment: "Machine", kind: .weighted),
    Exercise(name: "Hip thrust", muscleGroup: "Legs",
             equipment: "Barbell", kind: .weighted),
    Exercise(name: "Lunge", muscleGroup: "Legs",
             equipment: "Dumbbell", kind: .weighted),
    Exercise(name: "Cable crunch", muscleGroup: "Core",
             equipment: "Cable", kind: .weighted),
    Exercise(name: "Russian twist", muscleGroup: "Core",
             equipment: "Bodyweight", kind: .bodyweight),
    Exercise(name: "Cycling", muscleGroup: "Cardio",
             equipment: "Bike", kind: .cardio),
    Exercise(name: "Rowing machine", muscleGroup: "Cardio",
             equipment: "Machine", kind: .cardio),
    Exercise(name: "Jump rope", muscleGroup: "Cardio",
             equipment: "Bodyweight", kind: .timed),
]

/// Starter routines, resolved against the exercise list by name.
public func seedRoutines(exercises: [Exercise]) -> [Routine] {
    func id(_ name: String) -> UUID? {
        exercises.first { $0.name == name }?.id
    }
    func items(_ names: [(String, Int)]) -> [RoutineItem] {
        names.compactMap { name, sets in
            id(name).map { RoutineItem(exerciseId: $0, targetSets: sets) }
        }
    }
    return [
        Routine(name: "Full body A", items: items([
            ("Squat", 3), ("Bench press", 3),
            ("Barbell row", 3), ("Plank", 2)])),
        Routine(name: "Full body B", items: items([
            ("Deadlift", 3), ("Overhead press", 3),
            ("Pull-up", 3), ("Biceps curl", 2)])),
        Routine(name: "Push (chest, shoulders, triceps)", items: items([
            ("Bench press", 4), ("Incline bench press", 3),
            ("Overhead press", 3), ("Lateral raise", 3),
            ("Skull crusher", 3)])),
        Routine(name: "Pull (back, biceps)", items: items([
            ("Deadlift", 3), ("Lat pulldown", 3),
            ("Seated cable row", 3), ("Face pull", 3),
            ("Biceps curl", 3), ("Hammer curl", 2)])),
        Routine(name: "Legs", items: items([
            ("Squat", 4), ("Romanian deadlift", 3),
            ("Leg press", 3), ("Leg curl", 3), ("Calf raise", 4)])),
        Routine(name: "Cardio + core", items: items([
            ("Running", 1), ("Cycling", 1),
            ("Plank", 3), ("Cable crunch", 3)])),
    ]
}
