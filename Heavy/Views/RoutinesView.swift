import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Query(sort: \Routine.name, order: .forward) private var routines: [Routine]
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingNewRoutine = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label("No Routines Yet", systemImage: "dumbbell")
                    } description: {
                        Text("Create your first routine to start planning workouts.")
                    } actions: {
                        Button("Create Routine") {
                            isPresentingNewRoutine = true
                        }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(filteredRoutines) { routine in
                            NavigationLink(value: routine) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(routine.name)
                                        .font(.headline)

                                    HStack(spacing: 12) {
                                        Label("\(routine.exercises.count) exercises", systemImage: "list.bullet")
                                        if let date = routine.lastWorkoutDate {
                                            Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                                        } else {
                                            Label("Not trained yet", systemImage: "clock")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    duplicateRoutine(routine)
                                } label: {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Routines")
            .searchable(text: $searchText, prompt: "Search routines")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresentingNewRoutine = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewRoutine) {
                NewRoutineView { name, exerciseDrafts in
                    addRoutine(name: name, exerciseDrafts: exerciseDrafts)
                }
            }
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine)
            }
        }
    }

    private func addRoutine(name: String, exerciseDrafts: [RoutineExerciseDraft]) {
        let routine = Routine(name: name)
        routine.updatedAt = Date()

        for (index, draft) in exerciseDrafts.enumerated() {
            let exercise = RoutineExercise(name: draft.name, order: index)
            exercise.notes = encodeDraftDefaults(draft)
            modelContext.insert(exercise)
            routine.exercises.append(exercise)
        }

        modelContext.insert(routine)
    }

    private func encodeDraftDefaults(_ draft: RoutineExerciseDraft) -> String {
        let header = "__heavy_defaults__:sets=\(draft.sets.count);rest=\(draft.restSeconds ?? 0)"
        let trimmedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNotes.isEmpty else {
            return header
        }
        return "\(header)\n\(trimmedNotes)"
    }

    private func duplicateRoutine(_ original: Routine) {
        let duplicated = Routine(name: "\(original.name) Copy")
        duplicated.createdAt = Date()
        duplicated.updatedAt = Date()

        for exercise in original.exercises.sorted(by: { $0.order < $1.order }) {
            let copy = RoutineExercise(name: exercise.name, order: exercise.order)
            copy.notes = exercise.notes
            modelContext.insert(copy)
            duplicated.exercises.append(copy)
        }

        modelContext.insert(duplicated)
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { filteredRoutines[$0] }.forEach { modelContext.delete($0) }
    }

    private var filteredRoutines: [Routine] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return routines
        }
        return routines.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}

private struct NewRoutineView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @State private var routineTitle = ""
    @State private var exercises: [RoutineExerciseDraft] = []
    @State private var isPresentingExerciseSheet = false
    @State private var showHelpBanner = true
    var onCreate: (String, [RoutineExerciseDraft]) -> Void

    private var trimmedTitle: String {
        routineTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if showHelpBanner {
                        HStack(spacing: 12) {
                            Text("You're creating a Routine. Tap for help...")
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                showHelpBanner = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.yellow.opacity(0.45))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Routine title", text: $routineTitle)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.primary)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)

                        Divider()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    if exercises.isEmpty {
                        VStack(spacing: 18) {
                            Image(systemName: "dumbbell")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)

                            Text("Get started by adding an exercise to your routine.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)

                            Button {
                                isPresentingExerciseSheet = true
                            } label: {
                                Label("Add exercise", systemImage: "plus")
                                    .font(.title3.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.horizontal, 16)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        VStack(spacing: 14) {
                            ForEach($exercises) { $exercise in
                                RoutineDraftExerciseCard(
                                    exercise: $exercise,
                                    onRemove: {
                                        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                                            exercises.remove(at: index)
                                        }
                                    }
                                )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
                                                exercises.remove(at: index)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }

                            Button {
                                isPresentingExerciseSheet = true
                            } label: {
                                Label("Add exercise", systemImage: "plus")
                                    .font(.title3.weight(.medium))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 30)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Create Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onCreate(
                            trimmedTitle,
                            exercises
                        )
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $isPresentingExerciseSheet) {
                AddRoutineExerciseSheet { exerciseName in
                    let trimmed = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    var draft = RoutineExerciseDraft(name: trimmed)
                    draft.restSeconds = max(0, defaultRestSeconds)
                    exercises.append(draft)
                }
            }
        }
    }
}

private struct RoutineDraftExerciseCard: View {
    @Binding var exercise: RoutineExerciseDraft
    let onRemove: () -> Void
    @State private var isPresentingRestTimerPicker = false
    @State private var restSelectionSeconds = 0
    @State private var revealedSetID: UUID?
    @State private var setOffsets: [UUID: CGFloat] = [:]

    private let restOptions = [0, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]
    private let deleteRevealWidth: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.secondary)
                    )

                Text(exercise.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)

                Spacer()

                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            TextField("Add routine notes here", text: $exercise.notes)
                .font(.title3)
                .foregroundStyle(.secondary)

            Button {
                restSelectionSeconds = exercise.restSeconds ?? 0
                isPresentingRestTimerPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("Rest Timer: \(restLabel)")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .font(.title3)
            .foregroundStyle(.tint)
            .buttonStyle(.plain)

            HStack {
                Text("SET")
                Spacer()
                Text("KG")
                Spacer()
                Text("REPS")
            }
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                setRow(index: index, set: set)
            }

            Button {
                exercise.sets.append(.init())
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.title3.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $isPresentingRestTimerPicker) {
            NavigationStack {
                VStack(spacing: 0) {
                    Picker("Rest Time", selection: $restSelectionSeconds) {
                        ForEach(restOptions, id: \.self) { seconds in
                            Text(seconds == 0 ? "OFF" : "\(seconds)s")
                                .tag(seconds)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()

                    Button("Done") {
                        exercise.restSeconds = restSelectionSeconds == 0 ? nil : restSelectionSeconds
                        isPresentingRestTimerPicker = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(16)
                }
                .navigationTitle("Rest Timer")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
    }

    private var restLabel: String {
        guard let seconds = exercise.restSeconds, seconds > 0 else {
            return "OFF"
        }
        return "\(seconds)s"
    }

    private func removeSet(id: UUID) {
        guard exercise.sets.count > 1 else {
            return
        }
        exercise.sets.removeAll { $0.id == id }
        revealedSetID = nil
        setOffsets[id] = nil
    }

    private func setRow(index: Int, set: RoutineExerciseDraftSet) -> some View {
        let isDeletable = exercise.sets.count > 1
        let baseOffset: CGFloat = (revealedSetID == set.id && isDeletable) ? -deleteRevealWidth : 0
        let dragOffset = setOffsets[set.id] ?? 0
        let totalOffset = min(0, max(-deleteRevealWidth, baseOffset + dragOffset))
        let revealProgress = max(0, min(1, -totalOffset / deleteRevealWidth))

        return ZStack(alignment: .trailing) {
            if isDeletable {
                Button(role: .destructive) {
                    removeSet(id: set.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: deleteRevealWidth, height: 44)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
                .opacity(revealProgress)
            }

            HStack {
                Text("\(index + 1)")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(set.weight.isEmpty ? "-" : set.weight)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(set.reps.isEmpty ? "-" : set.reps)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background((index + 1).isMultiple(of: 2) ? Color(uiColor: .tertiarySystemFill) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .offset(x: totalOffset)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard isDeletable else { return }
                        if revealedSetID != set.id {
                            revealedSetID = nil
                        }
                        let clamped = max(-deleteRevealWidth, min(0, value.translation.width))
                        setOffsets[set.id] = clamped
                    }
                    .onEnded { value in
                        guard isDeletable else { return }
                        let shouldReveal = value.translation.width < -40
                        revealedSetID = shouldReveal ? set.id : nil
                        setOffsets[set.id] = 0
                    }
            )
            .onTapGesture {
                if revealedSetID == set.id {
                    revealedSetID = nil
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: revealedSetID)
    }
}

struct RoutineExerciseDraft: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var notes: String = ""
    var restSeconds: Int? = nil
    var sets: [RoutineExerciseDraftSet] = [.init(), .init()]
}

struct RoutineExerciseDraftSet: Identifiable, Hashable {
    var id = UUID()
    var weight: String = ""
    var reps: String = ""
}

private struct AddRoutineExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exerciseName = ""
    @State private var selectedExerciseName: String?
    @State private var selectedEquipment = "All equipments"
    @State private var selectedMuscle = "All muscles"
    var onAdd: (String) -> Void

    private let equipmentOptions = [
        "All equipments",
        "None",
        "Barbell",
        "Dumbbell",
        "Kettlebell",
        "Machine",
        "Plate"
    ]

    private let muscleOptions = [
        "All muscles",
        "Abdominals",
        "Biceps",
        "Calves",
        "Cardio",
        "Chest",
        "Forearms",
        "Full Body",
        "Glutes",
        "Lats",
        "Hamstrings",
        "Triceps",
        "Shoulders",
        "Quadriceps",
        "Traps",
        "Lower Back",
        "Upper Back",
        "Obliques",
        "Neck",
        "Other"
    ]

    private var normalizedSearch: String {
        exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredExercises: [ExerciseCatalogItem] {
        ExerciseCatalog.items.filter { exercise in
            let equipmentMatches = selectedEquipment == "All equipments" || exercise.equipment == selectedEquipment
            let muscleMatches = selectedMuscle == "All muscles" || exercise.muscle == selectedMuscle

            let query = normalizedSearch.lowercased()
            let textMatches = query.isEmpty || exercise.name.lowercased().contains(query)

            return equipmentMatches && muscleMatches && textMatches
        }
    }

    private var popularExercises: [ExerciseCatalogItem] {
        filteredExercises.filter { $0.isPopular }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Search exercises", text: $exerciseName)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)

                HStack(spacing: 10) {
                    Menu {
                        ForEach(equipmentOptions, id: \.self) { option in
                            Button {
                                selectedEquipment = option
                            } label: {
                                if selectedEquipment == option {
                                    Label(option, systemImage: "checkmark")
                                } else {
                                    Text(option)
                                }
                            }
                        }
                    } label: {
                        filterButtonLabel(value: selectedEquipment)
                    }

                    Menu {
                        ForEach(muscleOptions, id: \.self) { option in
                            Button {
                                selectedMuscle = option
                            } label: {
                                if selectedMuscle == option {
                                    Label(option, systemImage: "checkmark")
                                } else {
                                    Text(option)
                                }
                            }
                        }
                    } label: {
                        filterButtonLabel(value: selectedMuscle)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if normalizedSearch.isEmpty {
                            sectionTitle("Popular Exercises")

                            if popularExercises.isEmpty {
                                Text("No popular exercises for this filter.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(popularExercises.prefix(12)) { exercise in
                                            Button {
                                                selectedExerciseName = exercise.name
                                                exerciseName = exercise.name
                                            } label: {
                                                Text(exercise.name)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundStyle(selectedExerciseName == exercise.name ? Color.white : Color.primary)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        Capsule(style: .continuous)
                                                            .fill(selectedExerciseName == exercise.name ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        sectionTitle(normalizedSearch.isEmpty ? "All Exercises" : "Matching Exercises")

                        if filteredExercises.isEmpty {
                            ContentUnavailableView {
                                Label("No Exercises Found", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try a different search or filter.")
                            }
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredExercises) { exercise in
                                    Button {
                                        selectedExerciseName = exercise.name
                                        exerciseName = exercise.name
                                    } label: {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(exercise.name)
                                                    .font(.body)
                                                    .foregroundStyle(.primary)

                                                Text("\(exercise.muscle) • \(exercise.equipment)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            if selectedExerciseName == exercise.name {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.tint)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    if exercise.id != filteredExercises.last?.id {
                                        Divider()
                                            .padding(.leading, 12)
                                    }
                                }
                            }
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
            .padding(16)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(normalizedSearch)
                        dismiss()
                    }
                    .disabled(normalizedSearch.isEmpty)
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func filterButtonLabel(value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity)
    }
}

private struct ExerciseCatalogItem: Identifiable, Hashable {
    let name: String
    let equipment: String
    let muscle: String
    let isPopular: Bool

    var id: String { name }
}

private enum ExerciseCatalog {
    static let items: [ExerciseCatalogItem] = [
        .init(name: "Bench Press", equipment: "Barbell", muscle: "Chest", isPopular: true),
        .init(name: "Incline Bench Press", equipment: "Barbell", muscle: "Chest", isPopular: true),
        .init(name: "Decline Bench Press", equipment: "Barbell", muscle: "Chest", isPopular: false),
        .init(name: "Dumbbell Bench Press", equipment: "Dumbbell", muscle: "Chest", isPopular: true),
        .init(name: "Incline Dumbbell Press", equipment: "Dumbbell", muscle: "Chest", isPopular: true),
        .init(name: "Chest Fly", equipment: "Dumbbell", muscle: "Chest", isPopular: false),
        .init(name: "Cable Fly", equipment: "Machine", muscle: "Chest", isPopular: false),
        .init(name: "Push-Up", equipment: "None", muscle: "Chest", isPopular: true),
        .init(name: "Machine Chest Press", equipment: "Machine", muscle: "Chest", isPopular: false),

        .init(name: "Pull-Up", equipment: "None", muscle: "Lats", isPopular: true),
        .init(name: "Lat Pulldown", equipment: "Machine", muscle: "Lats", isPopular: true),
        .init(name: "Barbell Row", equipment: "Barbell", muscle: "Upper Back", isPopular: true),
        .init(name: "Dumbbell Row", equipment: "Dumbbell", muscle: "Upper Back", isPopular: true),
        .init(name: "Seated Cable Row", equipment: "Machine", muscle: "Upper Back", isPopular: true),
        .init(name: "T-Bar Row", equipment: "Barbell", muscle: "Upper Back", isPopular: false),
        .init(name: "Face Pull", equipment: "Machine", muscle: "Traps", isPopular: false),
        .init(name: "Straight Arm Pulldown", equipment: "Machine", muscle: "Lats", isPopular: false),

        .init(name: "Back Squat", equipment: "Barbell", muscle: "Quadriceps", isPopular: true),
        .init(name: "Front Squat", equipment: "Barbell", muscle: "Quadriceps", isPopular: false),
        .init(name: "Leg Press", equipment: "Machine", muscle: "Quadriceps", isPopular: true),
        .init(name: "Walking Lunge", equipment: "Dumbbell", muscle: "Glutes", isPopular: false),
        .init(name: "Bulgarian Split Squat", equipment: "Dumbbell", muscle: "Glutes", isPopular: true),
        .init(name: "Romanian Deadlift", equipment: "Barbell", muscle: "Hamstrings", isPopular: true),
        .init(name: "Stiff Leg Deadlift", equipment: "Barbell", muscle: "Hamstrings", isPopular: false),
        .init(name: "Leg Curl", equipment: "Machine", muscle: "Hamstrings", isPopular: false),
        .init(name: "Leg Extension", equipment: "Machine", muscle: "Quadriceps", isPopular: false),
        .init(name: "Hip Thrust", equipment: "Barbell", muscle: "Glutes", isPopular: true),
        .init(name: "Glute Bridge", equipment: "None", muscle: "Glutes", isPopular: false),
        .init(name: "Standing Calf Raise", equipment: "Machine", muscle: "Calves", isPopular: false),
        .init(name: "Seated Calf Raise", equipment: "Machine", muscle: "Calves", isPopular: false),

        .init(name: "Overhead Press", equipment: "Barbell", muscle: "Shoulders", isPopular: true),
        .init(name: "Dumbbell Shoulder Press", equipment: "Dumbbell", muscle: "Shoulders", isPopular: true),
        .init(name: "Lateral Raise", equipment: "Dumbbell", muscle: "Shoulders", isPopular: true),
        .init(name: "Front Raise", equipment: "Dumbbell", muscle: "Shoulders", isPopular: false),
        .init(name: "Rear Delt Fly", equipment: "Dumbbell", muscle: "Shoulders", isPopular: false),
        .init(name: "Upright Row", equipment: "Barbell", muscle: "Shoulders", isPopular: false),
        .init(name: "Shrug", equipment: "Dumbbell", muscle: "Traps", isPopular: false),

        .init(name: "Barbell Curl", equipment: "Barbell", muscle: "Biceps", isPopular: true),
        .init(name: "Dumbbell Curl", equipment: "Dumbbell", muscle: "Biceps", isPopular: true),
        .init(name: "Hammer Curl", equipment: "Dumbbell", muscle: "Biceps", isPopular: true),
        .init(name: "Preacher Curl", equipment: "Machine", muscle: "Biceps", isPopular: false),
        .init(name: "Cable Curl", equipment: "Machine", muscle: "Biceps", isPopular: false),
        .init(name: "Triceps Pushdown", equipment: "Machine", muscle: "Triceps", isPopular: true),
        .init(name: "Skull Crusher", equipment: "Barbell", muscle: "Triceps", isPopular: true),
        .init(name: "Dips", equipment: "None", muscle: "Triceps", isPopular: true),
        .init(name: "Overhead Triceps Extension", equipment: "Dumbbell", muscle: "Triceps", isPopular: false),
        .init(name: "Close Grip Bench Press", equipment: "Barbell", muscle: "Triceps", isPopular: false),

        .init(name: "Deadlift", equipment: "Barbell", muscle: "Lower Back", isPopular: true),
        .init(name: "Rack Pull", equipment: "Barbell", muscle: "Lower Back", isPopular: false),
        .init(name: "Back Extension", equipment: "Machine", muscle: "Lower Back", isPopular: false),
        .init(name: "Good Morning", equipment: "Barbell", muscle: "Lower Back", isPopular: false),
        .init(name: "Superman Hold", equipment: "None", muscle: "Lower Back", isPopular: false),

        .init(name: "Plank", equipment: "None", muscle: "Abdominals", isPopular: true),
        .init(name: "Cable Crunch", equipment: "Machine", muscle: "Abdominals", isPopular: false),
        .init(name: "Hanging Leg Raise", equipment: "None", muscle: "Abdominals", isPopular: true),
        .init(name: "Crunch", equipment: "None", muscle: "Abdominals", isPopular: false),
        .init(name: "Russian Twist", equipment: "Plate", muscle: "Obliques", isPopular: false),
        .init(name: "Side Plank", equipment: "None", muscle: "Obliques", isPopular: false),
        .init(name: "Mountain Climbers", equipment: "None", muscle: "Cardio", isPopular: false),
        .init(name: "Burpee", equipment: "None", muscle: "Cardio", isPopular: true),

        .init(name: "Kettlebell Swing", equipment: "Kettlebell", muscle: "Full Body", isPopular: true),
        .init(name: "Goblet Squat", equipment: "Kettlebell", muscle: "Quadriceps", isPopular: false),
        .init(name: "Turkish Get-Up", equipment: "Kettlebell", muscle: "Full Body", isPopular: false),
        .init(name: "Kettlebell Clean", equipment: "Kettlebell", muscle: "Full Body", isPopular: false),

        .init(name: "Wrist Curl", equipment: "Dumbbell", muscle: "Forearms", isPopular: false),
        .init(name: "Reverse Wrist Curl", equipment: "Dumbbell", muscle: "Forearms", isPopular: false),
        .init(name: "Farmer's Carry", equipment: "Dumbbell", muscle: "Forearms", isPopular: false),
        .init(name: "Plate Pinch Hold", equipment: "Plate", muscle: "Forearms", isPopular: false),

        .init(name: "Sled Push", equipment: "Machine", muscle: "Other", isPopular: false),
        .init(name: "Battle Rope", equipment: "Other", muscle: "Other", isPopular: false),
        .init(name: "Jump Rope", equipment: "None", muscle: "Cardio", isPopular: true),
        .init(name: "Neck Flexion", equipment: "Plate", muscle: "Neck", isPopular: false)
    ]
}

struct RoutinesView_Previews: PreviewProvider {
    static var previews: some View {
        RoutinesView()
            .modelContainer(try! ModelContainer(for: Routine.self, RoutineExercise.self, WorkoutSession.self, SetEntry.self))
    }
}
