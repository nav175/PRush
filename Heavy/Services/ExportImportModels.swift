import Foundation

struct WorkoutBackup: Codable {
    var version: Int = 1
    let routines: [RoutineBackup]
    let sessions: [WorkoutSessionBackup]
}

struct RoutineBackup: Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let exercises: [RoutineExerciseBackup]

    init(from model: Routine) {
        id = model.id
        name = model.name
        createdAt = model.createdAt
        updatedAt = model.updatedAt
        exercises = model.exercises.map { RoutineExerciseBackup(from: $0) }
    }
}

struct RoutineExerciseBackup: Codable {
    let id: UUID
    let name: String
    let notes: String
    let order: Int

    init(from model: RoutineExercise) {
        id = model.id
        name = model.name
        notes = model.notes
        order = model.order
    }
}

struct WorkoutSessionBackup: Codable {
    let id: UUID
    let routineName: String
    let date: Date
    let notes: String
    let weightUnitRaw: String?
    let sets: [SetEntryBackup]

    init(from model: WorkoutSession) {
        id = model.id
        routineName = model.routineName
        date = model.date
        notes = model.notes
        weightUnitRaw = model.weightUnitRaw
        sets = model.sets.map { SetEntryBackup(from: $0) }
    }
}

struct SetEntryBackup: Codable {
    let id: UUID
    let exerciseName: String?
    let reps: Int
    let weight: Double
    let restSeconds: Int?
    let isCompleted: Bool?
    let notes: String

    init(from model: SetEntry) {
        id = model.id
        exerciseName = model.exerciseName
        reps = model.reps
        weight = model.weight
        restSeconds = model.restSeconds
        isCompleted = model.isCompleted
        notes = model.notes
    }
}
