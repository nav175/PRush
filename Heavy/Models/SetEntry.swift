import Foundation
import SwiftData

@Model
class SetEntry {
    var id: UUID = UUID()
    var exerciseName: String = ""
    var reps: Int = 0
    var weight: Double = 0
    var restSeconds: Int = 90
    var isCompleted: Bool = false
    var notes: String = ""
    var createdAt: Date = Date()

    init(exerciseName: String = "", reps: Int = 0, weight: Double = 0, restSeconds: Int = 90, isCompleted: Bool = false) {
        self.exerciseName = exerciseName
        self.reps = reps
        self.weight = weight
        self.restSeconds = restSeconds
        self.isCompleted = isCompleted
    }
}
