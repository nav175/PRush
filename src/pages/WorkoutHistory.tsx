import { useWorkouts } from '../context/WorkoutsContext'
import WorkoutCard from '../components/WorkoutCard'
import './WorkoutHistory.css'

export default function WorkoutHistory() {
  const { workouts } = useWorkouts()

  const sorted = [...workouts].sort(
    (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime(),
  )

  const grouped: Record<string, typeof sorted> = {}
  sorted.forEach(w => {
    const month = new Date(w.date).toLocaleDateString('en-US', {
      month: 'long',
      year: 'numeric',
    })
    if (!grouped[month]) grouped[month] = []
    grouped[month].push(w)
  })

  return (
    <div className="history">
      <h1 className="page-title">Workout History</h1>
      {sorted.length === 0 ? (
        <div className="empty-state">
          <p className="empty-icon">📋</p>
          <p className="empty-text">No workouts logged yet.</p>
        </div>
      ) : (
        Object.entries(grouped).map(([month, monthWorkouts]) => (
          <div key={month} className="month-group">
            <h2 className="month-label">{month}</h2>
            <div className="workouts-list">
              {monthWorkouts.map(w => (
                <WorkoutCard key={w.id} workout={w} />
              ))}
            </div>
          </div>
        ))
      )}
    </div>
  )
}
