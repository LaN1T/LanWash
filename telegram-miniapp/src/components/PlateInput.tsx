import { formatPlate } from '../utils/validators'

interface PlateInputProps {
  value: string
  onChange: (value: string) => void
  placeholder?: string
  disabled?: boolean
  hasError?: boolean
}

export function PlateInput({
  value,
  onChange,
  placeholder = 'А 123 БВ 777',
  disabled = false,
  hasError = false,
}: PlateInputProps) {
  return (
    <div>
      <input
        style={{
          width: '100%',
          padding: '14px 16px',
          borderRadius: 12,
          border: `1px solid ${hasError ? '#DC2626' : '#E2E8F0'}`,
          fontSize: 15,
          background: '#FFFFFF',
          color: '#0F172A',
          outline: 'none',
          letterSpacing: value ? 1.5 : 0,
          fontWeight: value ? 600 : 400,
        }}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        maxLength={12}
        disabled={disabled}
      />
      {value && (
        <div
          style={{
            fontSize: 12,
            color: '#64748B',
            marginTop: 4,
            letterSpacing: 1.5,
            fontWeight: 600,
          }}
        >
          {formatPlate(value)}
        </div>
      )}
    </div>
  )
}
