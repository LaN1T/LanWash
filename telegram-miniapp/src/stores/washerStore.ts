import { create } from 'zustand'
import type { Appointment } from '../services/appointments'

interface WasherState {
  appointments: Appointment[]
  selectedDate: string
  loading: boolean
  error: string | null
  setAppointments: (appointments: Appointment[]) => void
  setSelectedDate: (date: string) => void
  setLoading: (loading: boolean) => void
  setError: (error: string | null) => void
}

export const useWasherStore = create<WasherState>((set) => ({
  appointments: [],
  selectedDate: '',
  loading: false,
  error: null,
  setAppointments: (appointments) => set({ appointments }),
  setSelectedDate: (selectedDate) => set({ selectedDate }),
  setLoading: (loading) => set({ loading }),
  setError: (error) => set({ error }),
}))