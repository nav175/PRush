import { Link } from 'react-router-dom'
import { useWorkouts } from '../hooks/useWorkouts'
import WorkoutCard from '../components/WorkoutCard'
import './Dashboard.css'

export default function Dashboard() {
  const { workouts } = useWorkouts()

  const now = new Date()
  const startOfWeek = new Date(now)
  startOfWeek.setDate(now.getDate() - now.getDay())
  startOfWeek.setHours(0, 0, 0, 0)

  const thisWeekCount = workouts.filter(w => new Date(w.date) >= startOfWeek).length
  const recentWorkouts = workouts.slice(0, 5)

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <div>
          <h1 className="dashboard-title">Dashboard</h1>
          <p className="dashboard-subtitle">Track your fitness journey</p>
        </div>
        <Link to="/workout/new" className="btn-primary">
          + Start Workout
        </Link>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <span className="stat-icon">🏋️</span>
          <div>
            <div className="stat-value">{workouts.length}</div>
            <div className="stat-label">Total Workouts</div>
          </div>
        </div>
        <div className="stat-card">
          <span className="stat-icon">📅</span>
          <div>
            <div className="stat-value">{thisWeekCount}</div>
            <div className="stat-label">This Week</div>
          </div>
        </div>
        <div className="stat-card">
          <span className="stat-icon">💪</span>
          <div>
            <div className="stat-value">
              {workouts.reduce((acc, w) => acc + w.exercises.length, 0)}
            </div>
            <div className="stat-label">Total Exercises</div>
          </div>
        </div>
      </div>

      <section className="recent-section">
        <h2 className="section-title">Recent Workouts</h2>
        {recentWorkouts.length === 0 ? (
          <div className="empty-state">
            <p className="empty-icon">🚀</p>
            <p className="empty-text">No workouts yet. Start your first one!</p>
            <Link to="/workout/new" className="btn-primary">
              Start First Workout
            </Link>
          </div>
        ) : (
          <div className="workouts-list">
            {recentWorkouts.map(w => (
              <WorkoutCard key={w.id} workout={w} />
            ))}
          </div>
        )}
        {workouts.length > 5 && (
          <Link to="/history" className="view-all-link">
            View all {workouts.length} workouts →
          </Link>
        )}
      </section>
    </div>
  )
}
