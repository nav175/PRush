import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { WorkoutsProvider } from './context/WorkoutsContext'
import Navbar from './components/Navbar'
import Dashboard from './pages/Dashboard'
import NewWorkout from './pages/NewWorkout'
import WorkoutHistory from './pages/WorkoutHistory'
import WorkoutDetail from './pages/WorkoutDetail'
import Progress from './pages/Progress'

function App() {
  return (
    <BrowserRouter>
      <WorkoutsProvider>
        <Navbar />
        <main className="main-content">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/workout/new" element={<NewWorkout />} />
            <Route path="/history" element={<WorkoutHistory />} />
            <Route path="/workout/:id" element={<WorkoutDetail />} />
            <Route path="/progress" element={<Progress />} />
          </Routes>
        </main>
      </WorkoutsProvider>
    </BrowserRouter>
  )
}

export default App
