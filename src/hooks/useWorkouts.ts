import { useState, useEffect, useCallback } from 'react'
import type { Workout } from '../types'

const STORAGE_KEY = 'prush_workouts'

function loadWorkouts(): Workout[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? (JSON.parse(raw) as Workout[]) : []
  } catch {
    return []
  }
}

function saveWorkouts(workouts: Workout[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(workouts))
}

export function useWorkouts() {
  const [workouts, setWorkouts] = useState<Workout[]>(loadWorkouts)

  useEffect(() => {
    saveWorkouts(workouts)
  }, [workouts])

  const addWorkout = useCallback((workout: Workout) => {
    setWorkouts(prev => [workout, ...prev])
  }, [])

  const deleteWorkout = useCallback((id: string) => {
    setWorkouts(prev => prev.filter(w => w.id !== id))
  }, [])

  const getWorkout = useCallback(
    (id: string) => workouts.find(w => w.id === id),
    [workouts],
  )

  return { workouts, addWorkout, deleteWorkout, getWorkout }
}
