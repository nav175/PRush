import { useState, useMemo } from 'react'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts'
import { useWorkouts } from '../context/WorkoutsContext'
import './Progress.css'

interface ChartPoint {
  isoDate: string
  date: string
  maxWeight: number
}

export default function Progress() {
  const { workouts } = useWorkouts()

  const exerciseNames = useMemo(() => {
    const names = new Set<string>()
    workouts.forEach(w => w.exercises.forEach(ex => names.add(ex.name)))
    return Array.from(names).sort()
  }, [workouts])

  const [selected, setSelected] = useState<string>(exerciseNames[0] ?? '')

  const chartData = useMemo((): ChartPoint[] => {
    if (!selected) return []

    const byDate: Record<string, { isoDate: string; maxWeight: number }> = {}
    workouts.forEach(w => {
      const ex = w.exercises.find(e => e.name === selected)
      if (!ex) return
      const maxWeight = Math.max(...ex.sets.map(s => s.weight))
      const dateKey = w.date.slice(0, 10) // YYYY-MM-DD for stable unique key
      if (byDate[dateKey] === undefined || maxWeight > byDate[dateKey].maxWeight) {
        byDate[dateKey] = { isoDate: w.date, maxWeight }
      }
    })

    return Object.entries(byDate)
      .sort(([a], [b]) => a.localeCompare(b)) // sort by YYYY-MM-DD string
      .map(([, { isoDate, maxWeight }]) => ({
        isoDate,
        date: new Date(isoDate).toLocaleDateString('en-US', {
          month: 'short',
          day: 'numeric',
        }),
        maxWeight,
      }))
  }, [workouts, selected])

  return (
    <div className="progress-page">
      <h1 className="page-title">Progress</h1>

      {exerciseNames.length === 0 ? (
        <div className="empty-state">
          <p className="empty-icon">📈</p>
          <p className="empty-text">Log some workouts to track progress.</p>
        </div>
      ) : (
        <>
          <div className="exercise-selector">
            <label className="form-label" htmlFor="exercise-select">
              Exercise
            </label>
            <select
              id="exercise-select"
              className="form-select"
              value={selected}
              onChange={e => setSelected(e.target.value)}
            >
              {exerciseNames.map(name => (
                <option key={name} value={name}>
                  {name}
                </option>
              ))}
            </select>
          </div>

          <div className="chart-card">
            <h2 className="chart-title">
              Max Weight — <span className="chart-exercise">{selected}</span>
            </h2>
            {chartData.length < 2 ? (
              <div className="chart-empty">
                <p>Need at least 2 sessions to show a trend.</p>
              </div>
            ) : (
              <ResponsiveContainer width="100%" height={320}>
                <LineChart data={chartData} margin={{ top: 10, right: 20, left: 0, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#0f3460" />
                  <XAxis
                    dataKey="date"
                    tick={{ fill: '#8892a4', fontSize: 12 }}
                    axisLine={{ stroke: '#0f3460' }}
                    tickLine={false}
                  />
                  <YAxis
                    tick={{ fill: '#8892a4', fontSize: 12 }}
                    axisLine={{ stroke: '#0f3460' }}
                    tickLine={false}
                    tickFormatter={v => `${v} lbs`}
                    width={70}
                  />
                  <Tooltip
                    contentStyle={{
                      background: '#16213e',
                      border: '1px solid #0f3460',
                      borderRadius: '8px',
                      color: '#e0e0e0',
                    }}
                    formatter={(value: number) => [`${value} lbs`, 'Max Weight']}
                  />
                  <Line
                    type="monotone"
                    dataKey="maxWeight"
                    stroke="#6C63FF"
                    strokeWidth={2.5}
                    dot={{ fill: '#6C63FF', r: 4, strokeWidth: 0 }}
                    activeDot={{ r: 6 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            )}
          </div>

          <div className="progress-summary">
            {chartData.length > 0 && (
              <>
                <div className="summary-stat">
                  <span className="summary-value">
                    {Math.max(...chartData.map(d => d.maxWeight))} lbs
                  </span>
                  <span className="summary-label">Personal Best</span>
                </div>
                <div className="summary-stat">
                  <span className="summary-value">{chartData.length}</span>
                  <span className="summary-label">Sessions</span>
                </div>
                {chartData.length >= 2 && (
                  <div className="summary-stat">
                    <span className={`summary-value ${chartData[chartData.length - 1].maxWeight >= chartData[0].maxWeight ? 'positive' : 'negative'}`}>
                      {chartData[chartData.length - 1].maxWeight >= chartData[0].maxWeight ? '▲' : '▼'}
                      {' '}
                      {Math.abs(chartData[chartData.length - 1].maxWeight - chartData[0].maxWeight)} lbs
                    </span>
                    <span className="summary-label">Overall Change</span>
                  </div>
                )}
              </>
            )}
          </div>
        </>
      )}
    </div>
  )
}
