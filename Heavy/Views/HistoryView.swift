import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink(value: session) {
                    VStack(alignment: .leading) {
                        Text(session.routineName)
                            .font(.headline)
                        Text(session.date, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Sets: \(session.sets.count) • Volume: \(Int(session.totalVolume))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("History")
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Workouts Logged", systemImage: "clock.badge.exclamationmark")
                } description: {
                    Text("Start a workout from any routine and it will appear here.")
                }
            }
        }
        .toolbar {
            if !sessions.isEmpty {
                EditButton()
            }
        }
        .navigationDestination(for: WorkoutSession.self) { session in
            HistoryDetailView(session: session)
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { sessions[$0] }.forEach { modelContext.delete($0) }
    }
}

private struct HistoryDetailView: View {
    @Bindable var session: WorkoutSession

    var body: some View {
        List {
            Section(header: Text("Session")) {
                Text(session.routineName)
                Text(session.date, style: .date)
                Text(session.date, style: .time)
                if !session.notes.isEmpty {
                    Text(session.notes)
                }
            }

            Section(header: Text("Sets")) {
                ForEach(session.sets.sorted(by: { $0.createdAt < $1.createdAt })) { set in
                    VStack(alignment: .leading) {
                        Text("\(set.reps) reps @ \(set.weight, specifier: "%.1f") \(session.weightUnit.symbol)")
                        if !set.notes.isEmpty {
                            Text(set.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout")
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .modelContainer(try! ModelContainer(for: Routine.self, RoutineExercise.self, WorkoutSession.self, SetEntry.self))
    }
}
