import SwiftUI
import SwiftData

@main
struct WorkoutApp: App {
    @State private var modelContainer = try! ModelContainer(for:
        Routine.self,
        RoutineExercise.self,
        WorkoutSession.self,
        SetEntry.self
    )

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(modelContainer)
                .environmentObject(BackupService())
                .tint(.blue)
        }
    }
}
