/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useState, useCallback, type ReactNode } from 'react'
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

interface WorkoutsContextValue {
  workouts: Workout[]
  addWorkout: (workout: Workout) => void
  deleteWorkout: (id: string) => void
  getWorkout: (id: string) => Workout | undefined
}

const WorkoutsContext = createContext<WorkoutsContextValue | null>(null)

export function WorkoutsProvider({ children }: { children: ReactNode }) {
  const [workouts, setWorkouts] = useState<Workout[]>(loadWorkouts)

  const addWorkout = useCallback((workout: Workout) => {
    setWorkouts(prev => {
      const next = [workout, ...prev]
      saveWorkouts(next)
      return next
    })
  }, [])

  const deleteWorkout = useCallback((id: string) => {
    setWorkouts(prev => {
      const next = prev.filter(w => w.id !== id)
      saveWorkouts(next)
      return next
    })
  }, [])

  const getWorkout = useCallback(
    (id: string) => workouts.find(w => w.id === id),
    [workouts],
  )

  return (
    <WorkoutsContext.Provider value={{ workouts, addWorkout, deleteWorkout, getWorkout }}>
      {children}
    </WorkoutsContext.Provider>
  )
}

export function useWorkouts(): WorkoutsContextValue {
  const ctx = useContext(WorkoutsContext)
  if (!ctx) throw new Error('useWorkouts must be used inside WorkoutsProvider')
  return ctx
}
