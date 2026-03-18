import { Link } from 'react-router-dom'
import type { Workout } from '../types'
import './WorkoutCard.css'

interface Props {
  workout: Workout
}

export default function WorkoutCard({ workout }: Props) {
  const date = new Date(workout.date)
  const formattedDate = date.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
  })
  const totalSets = workout.exercises.reduce((acc, ex) => acc + ex.sets.length, 0)

  return (
    <Link to={`/workout/${workout.id}`} className="workout-card">
      <div className="workout-card-header">
        <h3 className="workout-card-name">{workout.name}</h3>
        <span className="workout-card-date">{formattedDate}</span>
      </div>
      <div className="workout-card-meta">
        <span>{workout.exercises.length} exercise{workout.exercises.length !== 1 ? 's' : ''}</span>
        <span>·</span>
        <span>{totalSets} set{totalSets !== 1 ? 's' : ''}</span>
      </div>
      {workout.exercises.length > 0 && (
        <div className="workout-card-exercises">
          {workout.exercises.slice(0, 3).map(ex => (
            <span key={ex.id} className="exercise-tag">{ex.name}</span>
          ))}
          {workout.exercises.length > 3 && (
            <span className="exercise-tag more">+{workout.exercises.length - 3} more</span>
          )}
        </div>
      )}
    </Link>
  )
}
