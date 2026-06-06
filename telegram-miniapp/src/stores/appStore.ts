import { create } from 'zustand'

interface WashType {
  id: string
  name: string
  basePrice: number
  durationMinutes: number
}

interface Service {
  id: string
  name: string
  price: number
}

interface Appointment {
  id: string
  dateTime: string
  carModel: string
  carNumber: string
  status: string
  washTypeId: string
  box_index: number
}

interface AppState {
  appointments: Appointment[]
  services: Service[]
  washTypes: WashType[]
  setAppointments: (a: Appointment[]) => void
  setServices: (s: Service[]) => void
  setWashTypes: (w: WashType[]) => void
}

export const useAppStore = create<AppState>((set) => ({
  appointments: [],
  services: [],
  washTypes: [],
  setAppointments: (appointments) => set({ appointments }),
  setServices: (services) => set({ services }),
  setWashTypes: (washTypes) => set({ washTypes }),
}))