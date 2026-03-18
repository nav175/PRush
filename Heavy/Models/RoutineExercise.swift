import Foundation
import SwiftData

@Model
class RoutineExercise {
    var id: UUID = UUID()
    var name: String
    var notes: String = ""
    var order: Int = 0

    init(name: String, order: Int = 0) {
        self.name = name
        self.order = order
    }
}
