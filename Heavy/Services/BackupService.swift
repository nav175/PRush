import Foundation
import Combine
import SwiftData

@MainActor
class BackupService: ObservableObject {
    @Published var isBusy = false
    @Published var statusMessage: String?
    @Published var lastBackupDate: Date?

    func makeBackupData(context: ModelContext) -> Data? {
        let routines = try? context.fetch(FetchDescriptor<Routine>())
        let sessions = try? context.fetch(FetchDescriptor<WorkoutSession>())

        let backup = WorkoutBackup(
            routines: routines?.map { RoutineBackup(from: $0) } ?? [],
            sessions: sessions?.map { WorkoutSessionBackup(from: $0) } ?? []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    func importBackupData(_ data: Data, context: ModelContext) throws {
        let decoder = JSONDecoder()
        let backup = try decoder.decode(WorkoutBackup.self, from: data)

        // Merge imported items with existing items by UUID to prevent duplicates.
        // This allows re-importing the same file multiple times without creating duplicates.
        for routineBackup in backup.routines {
            let existing = (try? context.fetch(FetchDescriptor<Routine>()))?.first(where: { $0.id == routineBackup.id })
            if let existing {
                existing.name = routineBackup.name
                existing.createdAt = routineBackup.createdAt
                existing.updatedAt = routineBackup.updatedAt

                for exerciseBackup in routineBackup.exercises {
                    if let existingExercise = existing.exercises.first(where: { $0.id == exerciseBackup.id }) {
                        existingExercise.name = exerciseBackup.name
                        existingExercise.notes = exerciseBackup.notes
                        existingExercise.order = exerciseBackup.order
                    } else {
                        let exercise = RoutineExercise(name: exerciseBackup.name, order: exerciseBackup.order)
                        exercise.notes = exerciseBackup.notes
                        context.insert(exercise)
                        existing.exercises.append(exercise)
                    }
                }

            } else {
                let routine = Routine(name: routineBackup.name)
                routine.id = routineBackup.id
                routine.createdAt = routineBackup.createdAt
                routine.updatedAt = routineBackup.updatedAt

                for exerciseBackup in routineBackup.exercises {
                    let exercise = RoutineExercise(name: exerciseBackup.name, order: exerciseBackup.order)
                    exercise.id = exerciseBackup.id
                    exercise.notes = exerciseBackup.notes
                    context.insert(exercise)
                    routine.exercises.append(exercise)
                }

                context.insert(routine)
            }
        }

        for sessionBackup in backup.sessions {
            let existing = (try? context.fetch(FetchDescriptor<WorkoutSession>()))?.first(where: { $0.id == sessionBackup.id })
            if let existing {
                existing.routineName = sessionBackup.routineName
                existing.date = sessionBackup.date
                existing.notes = sessionBackup.notes
                existing.weightUnitRaw = sessionBackup.weightUnitRaw ?? existing.weightUnitRaw

                for setBackup in sessionBackup.sets {
                    if let existingSet = existing.sets.first(where: { $0.id == setBackup.id }) {
                        existingSet.exerciseName = setBackup.exerciseName ?? existingSet.exerciseName
                        existingSet.reps = setBackup.reps
                        existingSet.weight = setBackup.weight
                        existingSet.restSeconds = setBackup.restSeconds ?? existingSet.restSeconds
                        existingSet.isCompleted = setBackup.isCompleted ?? existingSet.isCompleted
                        existingSet.notes = setBackup.notes
                    } else {
                        let set = SetEntry(
                            exerciseName: setBackup.exerciseName ?? "",
                            reps: setBackup.reps,
                            weight: setBackup.weight,
                            restSeconds: setBackup.restSeconds ?? 90,
                            isCompleted: setBackup.isCompleted ?? false
                        )
                        set.id = setBackup.id
                        set.notes = setBackup.notes
                        context.insert(set)
                        existing.sets.append(set)
                    }
                }

            } else {
                let session = WorkoutSession(routineName: sessionBackup.routineName)
                session.id = sessionBackup.id
                session.date = sessionBackup.date
                session.notes = sessionBackup.notes
                session.weightUnitRaw = sessionBackup.weightUnitRaw ?? WeightUnit.lb.rawValue

                for setBackup in sessionBackup.sets {
                    let set = SetEntry(
                        exerciseName: setBackup.exerciseName ?? "",
                        reps: setBackup.reps,
                        weight: setBackup.weight,
                        restSeconds: setBackup.restSeconds ?? 90,
                        isCompleted: setBackup.isCompleted ?? false
                    )
                    set.id = setBackup.id
                    set.notes = setBackup.notes
                    context.insert(set)
                    session.sets.append(set)
                }

                context.insert(session)
            }
        }
    }
}
