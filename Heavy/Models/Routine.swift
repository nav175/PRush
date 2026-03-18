import Foundation
import SwiftData

@Model
class Routine {
    var id: UUID = UUID()
    var name: String
    @Relationship(deleteRule: .cascade) var exercises: [RoutineExercise] = []
    @Relationship(deleteRule: .cascade) var sessions: [WorkoutSession] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String) {
        self.name = name
    }

    var lastWorkoutDate: Date? {
        sessions.sorted(by: { $0.date > $1.date }).first?.date
    }
}
