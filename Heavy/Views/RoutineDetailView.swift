import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Bindable var routine: Routine
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferredWeightUnit") private var preferredWeightUnitRaw = WeightUnit.lb.rawValue
    @State private var isPresentingNewExercise = false
    @State private var isLoggingWorkout = false
    @State private var isPresentingTemplatePicker = false
    @State private var session: WorkoutSession? = nil

    var body: some View {
        List {
            Section(header: Text("Overview")) {
                LabeledContent("Exercises", value: "\(routine.exercises.count)")
                LabeledContent("Workouts", value: "\(routine.sessions.count)")
                LabeledContent("Total Sets", value: "\(routine.sessions.reduce(0) { $0 + $1.sets.count })")
            }

            Section(header: Text("Exercises")) {
                ForEach(routine.exercises.sorted(by: { $0.order < $1.order })) { exercise in
                    Text(exercise.name)
                }
                .onDelete(perform: delete)
                .onMove(perform: move)

                Button(action: { isPresentingNewExercise = true }) {
                    Label("Add Exercise", systemImage: "plus")
                }
            }

            Section(header: Text("Templates")) {
                Button {
                    isPresentingTemplatePicker = true
                } label: {
                    Label("Select Template", systemImage: "square.grid.2x2")
                }
            }

            Section {
                Button(action: startWorkout) {
                    Text("Start Workout")
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(routine.name)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $isPresentingNewExercise) {
            NewExerciseView { name in
                addExercise(name: name)
            }
        }
        .sheet(isPresented: $isPresentingTemplatePicker) {
            TemplatePickerSheet(
                onPush: {
                    addTemplate(["Bench Press", "Incline Dumbbell Press", "Triceps Pushdown", "Lateral Raise"])
                    isPresentingTemplatePicker = false
                },
                onPull: {
                    addTemplate(["Barbell Row", "Lat Pulldown", "Seated Cable Row", "Biceps Curl"])
                    isPresentingTemplatePicker = false
                },
                onLegs: {
                    addTemplate(["Back Squat", "Romanian Deadlift", "Leg Press", "Calf Raise"])
                    isPresentingTemplatePicker = false
                }
            )
            .presentationDetents([.height(240)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(uiColor: .systemBackground))
        }
        .navigationDestination(isPresented: $isLoggingWorkout) {
            if let session {
                WorkoutLoggerView(routine: routine, session: session)
            }
        }
    }

    private func startWorkout() {
        let newSession = WorkoutSession(routineName: routine.name)
        newSession.weightUnitRaw = WeightUnit(rawValue: preferredWeightUnitRaw)?.rawValue ?? WeightUnit.lb.rawValue
        modelContext.insert(newSession)
        routine.sessions.append(newSession)
        session = newSession
        isLoggingWorkout = true
    }

    private func addExercise(name: String) {
        let exercise = RoutineExercise(name: name, order: (routine.exercises.map { $0.order }.max() ?? -1) + 1)
        modelContext.insert(exercise)
        routine.exercises.append(exercise)
        routine.updatedAt = Date()
    }

    private func addTemplate(_ names: [String]) {
        let existing = Set(routine.exercises.map { $0.name.lowercased() })
        var nextOrder = (routine.exercises.map { $0.order }.max() ?? -1) + 1

        for name in names where !existing.contains(name.lowercased()) {
            let exercise = RoutineExercise(name: name, order: nextOrder)
            modelContext.insert(exercise)
            routine.exercises.append(exercise)
            nextOrder += 1
        }
        routine.updatedAt = Date()
    }

    private func delete(at offsets: IndexSet) {
        let items = offsets.map { routine.exercises.sorted(by: { $0.order < $1.order })[$0] }
        items.forEach { item in
            if let index = routine.exercises.firstIndex(where: { $0.id == item.id }) {
                routine.exercises.remove(at: index)
            }
            modelContext.delete(item)
        }
        routine.updatedAt = Date()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var updated = routine.exercises.sorted(by: { $0.order < $1.order })
        updated.move(fromOffsets: source, toOffset: destination)
        for (index, exercise) in updated.enumerated() {
            exercise.order = index
        }
        routine.exercises = updated
        routine.updatedAt = Date()
    }
}

private struct TemplatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPush: () -> Void
    let onPull: () -> Void
    let onLegs: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sheetRow("Push") {
                onPush()
                dismiss()
            }

            Divider()

            sheetRow("Pull") {
                onPull()
                dismiss()
            }

            Divider()

            sheetRow("Legs") {
                onLegs()
                dismiss()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(uiColor: .systemBackground))
    }

    private func sheetRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
        }
        .buttonStyle(.plain)
    }
}

private struct NewExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise name", text: $name)
            }
            .navigationTitle("New Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct RoutineDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: Routine.self, RoutineExercise.self, WorkoutSession.self, SetEntry.self)
        let context = container.mainContext
        let routine = Routine(name: "Push")
        context.insert(routine)
        let session = WorkoutSession(routineName: routine.name)
        context.insert(session)
        routine.sessions.append(session)

        return NavigationStack {
            RoutineDetailView(routine: routine)
        }
        .modelContainer(container)
    }
}
