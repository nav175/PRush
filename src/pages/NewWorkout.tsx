import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useWorkouts } from '../hooks/useWorkouts'
import type { Exercise, WorkoutSet } from '../types'
import './NewWorkout.css'

function generateId(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36)
}

function emptySet(): WorkoutSet {
  return { id: generateId(), reps: 0, weight: 0 }
}

function emptyExercise(): Exercise {
  return { id: generateId(), name: '', sets: [emptySet()] }
}

export default function NewWorkout() {
  const navigate = useNavigate()
  const { addWorkout } = useWorkouts()

  const [workoutName, setWorkoutName] = useState('')
  const [notes, setNotes] = useState('')
  const [exercises, setExercises] = useState<Exercise[]>([emptyExercise()])
  const [error, setError] = useState('')

  const updateExerciseName = (exId: string, name: string) => {
    setExercises(prev =>
      prev.map(ex => (ex.id === exId ? { ...ex, name } : ex)),
    )
  }

  const addExercise = () => {
    setExercises(prev => [...prev, emptyExercise()])
  }

  const removeExercise = (exId: string) => {
    setExercises(prev => prev.filter(ex => ex.id !== exId))
  }

  const addSet = (exId: string) => {
    setExercises(prev =>
      prev.map(ex =>
        ex.id === exId ? { ...ex, sets: [...ex.sets, emptySet()] } : ex,
      ),
    )
  }

  const removeSet = (exId: string, setId: string) => {
    setExercises(prev =>
      prev.map(ex =>
        ex.id === exId
          ? { ...ex, sets: ex.sets.filter(s => s.id !== setId) }
          : ex,
      ),
    )
  }

  const updateSet = (
    exId: string,
    setId: string,
    field: 'reps' | 'weight',
    value: string,
  ) => {
    const num = parseFloat(value) || 0
    setExercises(prev =>
      prev.map(ex =>
        ex.id === exId
          ? {
              ...ex,
              sets: ex.sets.map(s =>
                s.id === setId ? { ...s, [field]: num } : s,
              ),
            }
          : ex,
      ),
    )
  }

  const handleSave = () => {
    if (!workoutName.trim()) {
      setError('Please enter a workout name.')
      return
    }
    const validExercises = exercises.filter(ex => ex.name.trim())
    if (validExercises.length === 0) {
      setError('Add at least one exercise with a name.')
      return
    }
    setError('')
    addWorkout({
      id: generateId(),
      date: new Date().toISOString(),
      name: workoutName.trim(),
      exercises: validExercises,
      notes: notes.trim() || undefined,
    })
    navigate('/')
  }

  return (
    <div className="new-workout">
      <h1 className="page-title">New Workout</h1>

      {error && <div className="error-banner">{error}</div>}

      <div className="form-card">
        <div className="form-group">
          <label className="form-label">Workout Name</label>
          <input
            className="form-input"
            type="text"
            placeholder="e.g. Push Day, Leg Day..."
            value={workoutName}
            onChange={e => setWorkoutName(e.target.value)}
          />
        </div>
        <div className="form-group">
          <label className="form-label">Notes (optional)</label>
          <textarea
            className="form-input form-textarea"
            placeholder="How did it feel?"
            value={notes}
            onChange={e => setNotes(e.target.value)}
            rows={3}
          />
        </div>
      </div>

      <div className="exercises-section">
        <h2 className="section-title">Exercises</h2>

        {exercises.map((ex, exIndex) => (
          <div key={ex.id} className="exercise-card">
            <div className="exercise-header">
              <input
                className="form-input exercise-name-input"
                type="text"
                placeholder={`Exercise ${exIndex + 1} name`}
                value={ex.name}
                onChange={e => updateExerciseName(ex.id, e.target.value)}
              />
              {exercises.length > 1 && (
                <button
                  className="btn-icon danger"
                  onClick={() => removeExercise(ex.id)}
                  title="Remove exercise"
                >
                  ✕
                </button>
              )}
            </div>

            <div className="sets-table">
              <div className="sets-header">
                <span>Set</span>
                <span>Reps</span>
                <span>Weight (lbs)</span>
                <span></span>
              </div>
              {ex.sets.map((set, setIndex) => (
                <div key={set.id} className="set-row">
                  <span className="set-num">{setIndex + 1}</span>
                  <input
                    className="set-input"
                    type="number"
                    min="0"
                    placeholder="0"
                    value={set.reps || ''}
                    onChange={e => updateSet(ex.id, set.id, 'reps', e.target.value)}
                  />
                  <input
                    className="set-input"
                    type="number"
                    min="0"
                    step="0.5"
                    placeholder="0"
                    value={set.weight || ''}
                    onChange={e => updateSet(ex.id, set.id, 'weight', e.target.value)}
                  />
                  {ex.sets.length > 1 && (
                    <button
                      className="btn-icon danger small"
                      onClick={() => removeSet(ex.id, set.id)}
                    >
                      ✕
                    </button>
                  )}
                  {ex.sets.length === 1 && <span />}
                </div>
              ))}
            </div>

            <button className="btn-add-set" onClick={() => addSet(ex.id)}>
              + Add Set
            </button>
          </div>
        ))}

        <button className="btn-add-exercise" onClick={addExercise}>
          + Add Exercise
        </button>
      </div>

      <div className="save-row">
        <button className="btn-cancel" onClick={() => navigate(-1)}>
          Cancel
        </button>
        <button className="btn-save" onClick={handleSave}>
          Save Workout
        </button>
      </div>
    </div>
  )
}
