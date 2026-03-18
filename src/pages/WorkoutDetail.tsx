import { useParams, useNavigate } from 'react-router-dom'
import { useWorkouts } from '../hooks/useWorkouts'
import './WorkoutDetail.css'

export default function WorkoutDetail() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { getWorkout, deleteWorkout } = useWorkouts()

  const workout = id ? getWorkout(id) : undefined

  if (!workout) {
    return (
      <div className="detail-not-found">
        <p>Workout not found.</p>
        <button className="btn-back" onClick={() => navigate('/')}>
          Back to Dashboard
        </button>
      </div>
    )
  }

  const handleDelete = () => {
    if (confirm('Delete this workout? This cannot be undone.')) {
      deleteWorkout(workout.id)
      navigate('/history')
    }
  }

  const formattedDate = new Date(workout.date).toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })

  const totalSets = workout.exercises.reduce((acc, ex) => acc + ex.sets.length, 0)
  const totalVolume = workout.exercises.reduce(
    (acc, ex) =>
      acc + ex.sets.reduce((s, set) => s + set.reps * set.weight, 0),
    0,
  )

  return (
    <div className="workout-detail">
      <button className="btn-back" onClick={() => navigate(-1)}>
        ← Back
      </button>

      <div className="detail-header">
        <div>
          <h1 className="detail-name">{workout.name}</h1>
          <p className="detail-date">{formattedDate}</p>
        </div>
        <button className="btn-delete" onClick={handleDelete}>
          🗑 Delete
        </button>
      </div>

      <div className="detail-stats">
        <div className="detail-stat">
          <span className="detail-stat-value">{workout.exercises.length}</span>
          <span className="detail-stat-label">Exercises</span>
        </div>
        <div className="detail-stat">
          <span className="detail-stat-value">{totalSets}</span>
          <span className="detail-stat-label">Sets</span>
        </div>
        <div className="detail-stat">
          <span className="detail-stat-value">{totalVolume.toLocaleString()}</span>
          <span className="detail-stat-label">Total Volume (lbs)</span>
        </div>
      </div>

      {workout.notes && (
        <div className="detail-notes">
          <p className="notes-label">Notes</p>
          <p className="notes-text">{workout.notes}</p>
        </div>
      )}

      <div className="exercises-list">
        {workout.exercises.map(ex => {
          const maxWeight = Math.max(...ex.sets.map(s => s.weight))
          return (
            <div key={ex.id} className="exercise-block">
              <div className="exercise-block-header">
                <h3 className="exercise-block-name">{ex.name}</h3>
                <span className="exercise-block-max">
                  Max: {maxWeight} lbs
                </span>
              </div>
              <table className="sets-table">
                <thead>
                  <tr>
                    <th>Set</th>
                    <th>Reps</th>
                    <th>Weight (lbs)</th>
                    <th>Volume</th>
                  </tr>
                </thead>
                <tbody>
                  {ex.sets.map((set, i) => (
                    <tr key={set.id}>
                      <td>{i + 1}</td>
                      <td>{set.reps}</td>
                      <td>{set.weight}</td>
                      <td className="volume-cell">{set.reps * set.weight}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        })}
      </div>
    </div>
  )
}
