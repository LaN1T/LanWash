import { useState } from 'react'
import Step1CarWash from '../../components/BookingWizard/Step1CarWash'
import Step2DateTime from '../../components/BookingWizard/Step2DateTime'
import Step3Confirm from '../../components/BookingWizard/Step3Confirm'

export type BookingData = {
  clientName: string
  carModel: string
  carNumber: string
  washTypeId: string
  additionalServices: string[]
  dateTime: string
}

export default function BookingPage() {
  const [step, setStep] = useState(1)
  const [data, setData] = useState<BookingData>({
    clientName: '',
    carModel: '',
    carNumber: '',
    washTypeId: '',
    additionalServices: [],
    dateTime: '',
  })

  const updateData = (partial: Partial<BookingData>) => {
    setData((prev) => ({ ...prev, ...partial }))
  }

  return (
    <div style={{ padding: 20 }}>
      <h2 style={{ marginBottom: 16 }}>Запись на мойку</h2>
      <div style={{ marginBottom: 16, color: 'var(--tg-theme-hint-color)' }}>
        Шаг {step} из 3
      </div>
      {step === 1 && (
        <Step1CarWash data={data} updateData={updateData} onNext={() => setStep(2)} />
      )}
      {step === 2 && (
        <Step2DateTime data={data} updateData={updateData} onNext={() => setStep(3)} onBack={() => setStep(1)} />
      )}
      {step === 3 && (
        <Step3Confirm data={data} onBack={() => setStep(2)} />
      )}
    </div>
  )
}