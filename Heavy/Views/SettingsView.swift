import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var backupService: BackupService
    @Environment(\.modelContext) private var modelContext

    @AppStorage("preferredWeightUnit") private var preferredWeightUnitRaw = WeightUnit.lb.rawValue
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90

    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportData: Data?

    var body: some View {
        Form {
            Section(header: Text("Workout Preferences")) {
                Picker("Default Unit", selection: $preferredWeightUnitRaw) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.symbol.uppercased()).tag(unit.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(value: $defaultRestSeconds, in: 15...600, step: 15) {
                    Text("Default Rest Timer: \(defaultRestSeconds)s")
                }
            }

            Section(header: Text("Backup")) {
                Button(action: prepareExport) {
                    Label("Export backup", systemImage: "square.and.arrow.up")
                }
                .disabled(backupService.isBusy)

                Button(action: { isImporting = true }) {
                    Label("Import backup", systemImage: "square.and.arrow.down")
                }
                .disabled(backupService.isBusy)

                if let last = backupService.lastBackupDate {
                    Text("Last backup: \(last, style: .date) \(last, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let message = backupService.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .fileExporter(
            isPresented: $isExporting,
            document: BackupFile(data: exportData ?? Data()),
            contentType: UTType.json,
            defaultFilename: "WorkoutBackup"
        ) { result in
            switch result {
            case .success:
                backupService.statusMessage = "Backup saved."
            case .failure:
                backupService.statusMessage = "Export failed."
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importFromURL(url)
            case .failure:
                backupService.statusMessage = "Import failed."
            }
        }
    }

    private func prepareExport() {
        guard let data = backupService.makeBackupData(context: modelContext) else {
            backupService.statusMessage = "Nothing to export yet."
            return
        }
        exportData = data
        isExporting = true
        backupService.lastBackupDate = Date()
    }

    private func importFromURL(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            try backupService.importBackupData(data, context: modelContext)
            backupService.statusMessage = "Import complete."
        } catch {
            backupService.statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(BackupService())
            .modelContainer(try! ModelContainer(for: Routine.self, RoutineExercise.self, WorkoutSession.self, SetEntry.self))
    }
}
