import Foundation
import SwiftData

enum WeightUnit: String, CaseIterable, Identifiable, Codable {
    case lb
    case kg

    var id: String { rawValue }

    var symbol: String {
        rawValue
    }
}

@Model
class WorkoutSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var notes: String = ""
    var weightUnitRaw: String = WeightUnit.lb.rawValue
    @Relationship(deleteRule: .cascade) var sets: [SetEntry] = []
    var routineName: String = ""

    init(routineName: String) {
        self.routineName = routineName
    }

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .lb }
        set { weightUnitRaw = newValue.rawValue }
    }

    var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}
