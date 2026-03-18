import SwiftUI
import SwiftData
import Combine

struct WorkoutLoggerView: View {
    @Bindable var routine: Routine
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90
    @State private var now = Date()
    @State private var activeRestEndTime: Date?
    @State private var activeRestDuration: Int = 0
    @State private var restPresetSeconds = 90
    @State private var lastLiveActivityUpdate = Date.distantPast
    @State private var liveActivityManager = WorkoutLiveActivityManager()
    @State private var exerciseMenuTarget: String?
    @State private var exerciseNotes: [String: String] = [:]
    @State private var restPickerExerciseName: String?
    @State private var restPickerSeconds = 90
    @State private var showSaveScreen = false
    @State private var workoutEndTime: Date?

    private let secondTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                WorkoutStatsBar(
                    elapsedText: elapsedText,
                    volumeText: volumeText,
                    setsText: "\(completedSetCount)/\(session.sets.count)",
                    showRestIndicator: remainingRestSeconds != nil
                )

                ScrollView {
                    LazyVStack(spacing: 18) {
                        ForEach(exerciseNames, id: \.self) { exerciseName in
                            ExerciseCard(
                                exerciseName: exerciseName,
                                notes: Binding(
                                    get: { exerciseNotes[exerciseName, default: ""] },
                                    set: { exerciseNotes[exerciseName] = $0 }
                                ),
                                unit: session.weightUnit,
                                sets: sets(for: exerciseName),
                                restText: restText(for: exerciseName),
                                onRestTimerTapped: {
                                    openRestTimerPicker(for: exerciseName)
                                },
                                onMoreTapped: { exerciseMenuTarget = exerciseName },
                                onAddSet: { addSet(for: exerciseName) },
                                onToggleCompletion: { set in
                                    set.isCompleted.toggle()
                                    if set.isCompleted, set.restSeconds > 0 {
                                        startRestTimer(seconds: set.restSeconds)
                                    }
                                },
                                onDeleteSet: { set in
                                    removeSet(set)
                                },
                                previousTextProvider: { set in
                                    previousText(for: set, exerciseName: exerciseName)
                                }
                            )
                        }

                        Picker("Weight Unit", selection: weightUnitBinding) {
                            ForEach(WeightUnit.allCases) { unit in
                                Text(unit.symbol.uppercased()).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            restPresetSeconds = max(15, defaultRestSeconds)
            if session.sets.isEmpty {
                ensureInitialSets()
            }
            preloadRoutineNotes()
            liveActivityManager.start(session: session)
        }
        .onReceive(secondTicker) { tick in
            now = tick

            if let end = activeRestEndTime, tick >= end {
                stopRestTimer()
            }

            if tick.timeIntervalSince(lastLiveActivityUpdate) >= 15 {
                liveActivityManager.update(session: session, now: tick)
                lastLiveActivityUpdate = tick
            }
        }
        .onChange(of: restPresetSeconds) { _, newValue in
            defaultRestSeconds = newValue
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                liveActivityManager.update(session: session, now: Date())
            case .background:
                liveActivityManager.update(session: session, now: Date())
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .sheet(isPresented: exerciseMenuPresented) {
            ExerciseOptionsSheet(
                onReorder: { exerciseMenuTarget = nil },
                onReplace: { exerciseMenuTarget = nil },
                onSuperset: { exerciseMenuTarget = nil },
                onRemove: {
                    if let target = exerciseMenuTarget {
                        removeExercise(named: target)
                    }
                }
            )
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: restPickerPresented) {
            if let exerciseName = restPickerExerciseName {
                RestTimerPickerSheet(
                    exerciseName: exerciseName,
                    selectedSeconds: $restPickerSeconds,
                    onDone: {
                        applyRestTimerSelection(for: exerciseName)
                    }
                )
                .presentationDetents([.fraction(0.46)])
                .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $showSaveScreen) {
            WorkoutSaveView(
                routine: routine,
                session: session,
                elapsedText: elapsedText,
                volumeText: volumeText,
                setsText: "\(completedSetCount)/\(session.sets.count)",
                onSave: {
                    showSaveScreen = false
                    liveActivityManager.end()
                    dismiss()
                },
                onDiscard: {
                    modelContext.delete(session)
                    showSaveScreen = false
                    liveActivityManager.end()
                    dismiss()
                },
                onCancel: {
                    showSaveScreen = false
                }
            )
        }
    }

    private var exerciseMenuPresented: Binding<Bool> {
        Binding(
            get: { exerciseMenuTarget != nil },
            set: { if !$0 { exerciseMenuTarget = nil } }
        )
    }

    private var restPickerPresented: Binding<Bool> {
        Binding(
            get: { restPickerExerciseName != nil },
            set: { if !$0 { restPickerExerciseName = nil } }
        )
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }

            Text("Log Workout")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            if let remainingRestSeconds {
                Text("\(remainingRestSeconds)s")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
            }

            Image(systemName: "clock")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button(action: finishWorkout) {
                Text("Finish")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func ensureInitialSets() {
        if !routine.exercises.isEmpty {
            for exercise in routine.exercises.sorted(by: { $0.order < $1.order }) {
                let defaults = routineDefaults(for: exercise)
                let count = max(1, defaults.sets)
                for _ in 0..<count {
                    addSet(for: exercise.name, restSecondsOverride: defaults.restSeconds)
                }
            }
        } else {
            addSet(for: "Exercise")
        }
    }

    private func preloadRoutineNotes() {
        for exercise in routine.exercises {
            let cleanedNotes = strippedRoutineDefaults(from: exercise.notes)
            if !cleanedNotes.isEmpty {
                exerciseNotes[exercise.name] = cleanedNotes
            }
        }
    }

    private func addSet(for exerciseName: String, restSecondsOverride: Int? = nil) {
        let matching = sets(for: exerciseName)
        let template = matching.last
        let set = SetEntry(
            exerciseName: exerciseName,
            reps: template?.reps ?? 8,
            weight: template?.weight ?? 0,
            restSeconds: template?.restSeconds ?? restSecondsOverride ?? restPresetSeconds,
            isCompleted: false
        )
        set.notes = template?.notes ?? ""
        modelContext.insert(set)
        session.sets.append(set)
    }

    private func sets(for exerciseName: String) -> [SetEntry] {
        session.sets
            .filter { ($0.exerciseName.isEmpty ? exerciseName : $0.exerciseName) == exerciseName }
            .sorted(by: { $0.createdAt < $1.createdAt })
    }

    private func previousText(for set: SetEntry, exerciseName: String) -> String {
        let items = sets(for: exerciseName)
        guard let index = items.firstIndex(where: { $0.id == set.id }), index > 0 else {
            return "-"
        }
        let previous = items[index - 1]
        return "\(Int(previous.weight))\(session.weightUnit.symbol) x \(previous.reps)"
    }

    private func restText(for exerciseName: String) -> String {
        let items = sets(for: exerciseName)
        let seconds = items.last?.restSeconds ?? restPresetSeconds
        if seconds <= 0 {
            return "OFF"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes)min" : "\(minutes)min \(remainder)s"
    }

    private func removeExercise(named name: String) {
        if let exercise = routine.exercises.first(where: { $0.name == name }) {
            routine.exercises.removeAll { $0.id == exercise.id }
            modelContext.delete(exercise)
        }

        let setsToDelete = session.sets.filter { $0.exerciseName == name }
        for set in setsToDelete {
            modelContext.delete(set)
        }
        session.sets.removeAll { $0.exerciseName == name }
        exerciseMenuTarget = nil
    }

    private func removeSet(_ set: SetEntry) {
        let sameExerciseCount = session.sets.filter { $0.exerciseName == set.exerciseName }.count
        guard sameExerciseCount > 1 else {
            return
        }

        session.sets.removeAll { $0.id == set.id }
        modelContext.delete(set)
    }

    private func openRestTimerPicker(for exerciseName: String) {
        let current = sets(for: exerciseName).last?.restSeconds ?? restPresetSeconds
        restPickerSeconds = max(0, current)
        restPickerExerciseName = exerciseName
    }

    private func applyRestTimerSelection(for exerciseName: String) {
        for set in session.sets where set.exerciseName == exerciseName {
            set.restSeconds = restPickerSeconds
        }
        restPresetSeconds = restPickerSeconds
        restPickerExerciseName = nil
    }

    private var exerciseNames: [String] {
        let routineNames = routine.exercises
            .sorted(by: { $0.order < $1.order })
            .map { $0.name }
        let setNames = session.sets.map { $0.exerciseName }.filter { !$0.isEmpty }

        let combined = routineNames + setNames
        var seen = Set<String>()
        return combined.filter { name in
            if seen.contains(name) {
                return false
            }
            seen.insert(name)
            return true
        }
    }

    private var completedSetCount: Int {
        session.sets.filter { $0.isCompleted }.count
    }

    private var volumeText: String {
        "\(Int(session.totalVolume)) \(session.weightUnit.symbol)"
    }

    private func finishWorkout() {
        if workoutEndTime == nil {
            workoutEndTime = Date()
        }
        stopRestTimer()
        liveActivityManager.end()
        showSaveScreen = true
    }

    private func startRestTimer(seconds: Int) {
        activeRestDuration = max(15, seconds)
        activeRestEndTime = Date().addingTimeInterval(Double(activeRestDuration))
    }

    private func stopRestTimer() {
        activeRestEndTime = nil
        activeRestDuration = 0
    }

    private var weightUnitBinding: Binding<WeightUnit> {
        Binding(
            get: { session.weightUnit },
            set: { session.weightUnit = $0 }
        )
    }

    private var elapsedText: String {
        let referenceTime = workoutEndTime ?? now
        let elapsed = max(0, Int(referenceTime.timeIntervalSince(session.date)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var remainingRestSeconds: Int? {
        guard let activeRestEndTime else {
            return nil
        }
        let remaining = Int(ceil(activeRestEndTime.timeIntervalSince(now)))
        return max(0, remaining)
    }

    private func routineDefaults(for exercise: RoutineExercise) -> (sets: Int, restSeconds: Int?) {
        let prefix = "__heavy_defaults__:"
        guard let firstLine = exercise.notes.split(separator: "\n", omittingEmptySubsequences: false).first,
              firstLine.hasPrefix(prefix) else {
            return (1, nil)
        }

        let payload = firstLine.dropFirst(prefix.count)
        let parts = payload.split(separator: ";")
        var setCount = 1
        var restSeconds: Int? = nil

        for part in parts {
            let keyValue = part.split(separator: "=", maxSplits: 1)
            guard keyValue.count == 2 else { continue }
            let key = String(keyValue[0])
            let value = String(keyValue[1])

            if key == "sets", let parsedSets = Int(value), parsedSets > 0 {
                setCount = parsedSets
            }

            if key == "rest", let parsedRest = Int(value) {
                restSeconds = parsedRest > 0 ? parsedRest : nil
            }
        }

        return (setCount, restSeconds)
    }

    private func strippedRoutineDefaults(from notes: String) -> String {
        let prefix = "__heavy_defaults__:"
        let lines = notes.split(separator: "\n", omittingEmptySubsequences: false)
        guard let firstLine = lines.first, firstLine.hasPrefix(prefix) else {
            return notes
        }
        return lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ExerciseOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onReorder: () -> Void
    let onReplace: () -> Void
    let onSuperset: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                actionRow("Reorder Exercises") {
                    onReorder()
                }

                Divider()

                actionRow("Replace Exercise") {
                    onReplace()
                }

                Divider()

                actionRow("Add To Superset") {
                    onSuperset()
                }

                Divider()

                actionRow("Remove Exercise", isDestructive: true) {
                    onRemove()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color(uiColor: .systemBackground))
    }

    private func actionRow(_ title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutStatsBar: View {
    let elapsedText: String
    let volumeText: String
    let setsText: String
    let showRestIndicator: Bool

    var body: some View {
        HStack(spacing: 20) {
            statItem(title: "Duration", value: elapsedText)
            statItem(title: "Volume", value: volumeText)
            statItem(title: "Sets", value: setsText)

            HStack(spacing: 6) {
                Image(systemName: "figure.strengthtraining.traditional")
                Image(systemName: "figure.strengthtraining.functional")
            }
            .foregroundStyle(.secondary)

            if showRestIndicator {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.5))
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.5))
                .frame(height: 1)
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
                .foregroundStyle(.tint)
        }
    }
}

private struct ExerciseCard: View {
    let exerciseName: String
    @Binding var notes: String
    let unit: WeightUnit
    let sets: [SetEntry]
    let restText: String
    let onRestTimerTapped: () -> Void
    let onMoreTapped: () -> Void
    let onAddSet: () -> Void
    let onToggleCompletion: (SetEntry) -> Void
    let onDeleteSet: (SetEntry) -> Void
    let previousTextProvider: (SetEntry) -> String
    @State private var revealedSetID: UUID?
    @State private var setOffsets: [UUID: CGFloat] = [:]

    private let deleteRevealWidth: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.primary)
                    )

                Text(exerciseName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)

                Spacer()

                Button(action: onMoreTapped) {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }

            TextField("Add notes here...", text: $notes)
                .textInputAutocapitalization(.sentences)
                .foregroundStyle(.primary)

            Button(action: onRestTimerTapped) {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                    Text("Rest Timer: \(restText)")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .font(.title3)
            .foregroundStyle(.tint)

            ExerciseSetTableHeader(unit: unit)

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                swipeableSetRow(index: index, set: set)
            }

            Button(action: onAddSet) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Set")
                        .font(.title3.weight(.medium))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func swipeableSetRow(index: Int, set: SetEntry) -> some View {
        let isDeletable = sets.count > 1
        let baseOffset: CGFloat = (revealedSetID == set.id && isDeletable) ? -deleteRevealWidth : 0
        let dragOffset = setOffsets[set.id] ?? 0
        let totalOffset = min(0, max(-deleteRevealWidth, baseOffset + dragOffset))
        let revealProgress = max(0, min(1, -totalOffset / deleteRevealWidth))

        return ZStack(alignment: .trailing) {
            if isDeletable {
                Button(role: .destructive) {
                    onDeleteSet(set)
                    revealedSetID = nil
                    setOffsets[set.id] = nil
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: deleteRevealWidth, height: 44)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .opacity(revealProgress)
            }

            ExerciseSetRow(
                index: index,
                set: set,
                unit: unit,
                previousText: previousTextProvider(set)
            ) {
                onToggleCompletion(set)
            }
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

private struct RestTimerPickerSheet: View {
    let exerciseName: String
    @Binding var selectedSeconds: Int
    let onDone: () -> Void
    @State private var isShowingTimerSettings = false

    private let options = [0] + Array(stride(from: 15, through: 600, by: 5))

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 14)

            HStack {
                Spacer()
                Button {
                    isShowingTimerSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)

            Text("Rest Timer")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.top, 2)

            Text(exerciseName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Divider()
                .background(Color(uiColor: .separator).opacity(0.5))
                .padding(.top, 14)

            Picker("Rest Time", selection: $selectedSeconds) {
                ForEach(options, id: \.self) { value in
                    Text(format(seconds: value))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxHeight: 230)

            Button(action: onDone) {
                Text("Done")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(uiColor: .secondarySystemBackground).ignoresSafeArea())
        .sheet(isPresented: $isShowingTimerSettings) {
            TimerSettingsSheet(defaultSeconds: $selectedSeconds)
        }
    }

    private func format(seconds: Int) -> String {
        if seconds == 0 {
            return "OFF"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes)min" : "\(minutes)min \(remainder)s"
    }
}

private struct TimerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var defaultSeconds: Int
    @State private var isShowingDefaultPicker = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    // Placeholder for future sound options.
                } label: {
                    HStack {
                        Text("Sounds")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    isShowingDefaultPicker = true
                } label: {
                    HStack {
                        Text("Default Rest Timer")
                        Spacer()
                        Text(format(seconds: defaultSeconds))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .listStyle(.plain)
            .tint(.primary)

            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isShowingDefaultPicker) {
                DefaultRestTimerPickerSheet(selectedSeconds: $defaultSeconds)
                    .presentationDetents([.fraction(0.42)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color(uiColor: .secondarySystemBackground))
            }
        }
    }

    private func format(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes)min" : "\(minutes)min \(remainder)s"
    }
}

private struct DefaultRestTimerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSeconds: Int

    private let options = Array(stride(from: 15, through: 600, by: 5))

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Default Rest Timer")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 10)

                Picker("Default Rest", selection: $selectedSeconds) {
                    ForEach(options, id: \.self) { value in
                        Text(format(seconds: value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Button("Done") {
                    dismiss()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
    }

    private func format(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes)min" : "\(minutes)min \(remainder)s"
    }
}

private struct ExerciseSetTableHeader: View {
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 0) {
            Text("SET")
                .frame(width: 56, alignment: .leading)
            Text("PREVIOUS")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(unit.symbol.uppercased())")
                .frame(width: 86, alignment: .center)
            Text("REPS")
                .frame(width: 76, alignment: .center)
            Image(systemName: "checkmark")
                .frame(width: 44)
        }
        .font(.headline)
        .foregroundStyle(.secondary)
    }
}

private struct ExerciseSetRow: View {
    let index: Int
    @Bindable var set: SetEntry
    let unit: WeightUnit
    let previousText: String
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(index == 0 ? "W" : "\(index)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(index == 0 ? AnyShapeStyle(Color(red: 0.93, green: 0.74, blue: 0.15)) : AnyShapeStyle(.primary))
                .frame(width: 56, alignment: .leading)

            Text(previousText)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 86)

            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 76)

            Button(action: onToggleCompletion) {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.bordered)
            .tint(set.isCompleted ? .green : .gray)
            .frame(width: 44)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(index.isMultiple(of: 2) ? Color.clear : Color(uiColor: .tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WorkoutSaveView: View {
    @Environment(\.dismiss) private var dismiss
    let routine: Routine
    let session: WorkoutSession
    let elapsedText: String
    let volumeText: String
    let setsText: String
    let onSave: () -> Void
    let onDiscard: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(routine.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 12) {
                        statRow(title: "Duration", value: elapsedText)
                        statRow(title: "Volume", value: volumeText)
                        statRow(title: "Sets", value: setsText)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("When")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.body)
                        .foregroundStyle(.primary)

                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("Add a photo / video")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("How did your workout go? Leave some notes here...", text: .constant(""))
                            .textInputAutocapitalization(.sentences)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 16) {
                        settingRow(title: "Sync With", value: "Apple Health")
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Button(action: onDiscard) {
                            Text("Discard Workout")
                                .font(.headline)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onCancel) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(.primary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Save Workout")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: onSave)
                        .font(.headline)
                }
            }
        }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
        }
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
    }
}

struct WorkoutLoggerView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: Routine.self, RoutineExercise.self, WorkoutSession.self, SetEntry.self)
        let context = container.mainContext
        let routine = Routine(name: "Legs")
        context.insert(routine)

        let session = WorkoutSession(routineName: routine.name)
        context.insert(session)
        routine.sessions.append(session)

        return NavigationStack {
            WorkoutLoggerView(routine: routine, session: session)
        }
        .modelContainer(container)
    }
}
