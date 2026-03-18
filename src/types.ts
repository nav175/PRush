export interface WorkoutSet {
  id: string;
  reps: number;
  weight: number; // in lbs
}

export interface Exercise {
  id: string;
  name: string;
  sets: WorkoutSet[];
}

export interface Workout {
  id: string;
  date: string; // ISO string
  name: string;
  exercises: Exercise[];
  notes?: string;
}
