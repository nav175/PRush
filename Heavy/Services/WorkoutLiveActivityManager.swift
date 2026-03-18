import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var routineName: String
        var startDate: Date
        var elapsedSeconds: Int
    }

    var sessionID: String
}

@MainActor
final class WorkoutLiveActivityManager {
#if canImport(ActivityKit)
    private var activity: Activity<WorkoutActivityAttributes>?
#endif

    func start(session: WorkoutSession) {
#if canImport(ActivityKit)
        guard activity == nil else {
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let attributes = WorkoutActivityAttributes(sessionID: session.id.uuidString)
        let state = WorkoutActivityAttributes.ContentState(
            routineName: session.routineName,
            startDate: session.date,
            elapsedSeconds: max(0, Int(Date().timeIntervalSince(session.date)))
        )

        do {
            activity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date().addingTimeInterval(8 * 60 * 60)),
                pushType: nil
            )
        } catch {
            // Keep app flow resilient even if activity cannot be started.
        }
#endif
    }

    func update(session: WorkoutSession, now: Date = Date()) {
#if canImport(ActivityKit)
        guard let activity else {
            return
        }

        let state = WorkoutActivityAttributes.ContentState(
            routineName: session.routineName,
            startDate: session.date,
            elapsedSeconds: max(0, Int(now.timeIntervalSince(session.date)))
        )

        Task {
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(8 * 60 * 60)))
        }
#endif
    }

    func end() {
#if canImport(ActivityKit)
        guard let activity else {
            return
        }

        let finalState = WorkoutActivityAttributes.ContentState(
            routineName: "Workout Complete",
            startDate: Date(),
            elapsedSeconds: 0
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        self.activity = nil
#endif
    }
}
