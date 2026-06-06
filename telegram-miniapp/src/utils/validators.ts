// License plate validation - Russian format: А123БВ777
const PLATE_LETTERS = 'АВЕКМНОРСТУХ'
const PLATE_REGEX = new RegExp(`^[${PLATE_LETTERS}]\\d{3}[${PLATE_LETTERS}]{2}\\d{2,3}$`)

export function validatePlate(plate: string): string | null {
  const cleaned = plate.replace(/\s/g, '').toUpperCase()
  if (!cleaned) return 'Введите госномер'
  if (!PLATE_REGEX.test(cleaned)) {
    return 'Формат: А123БВ777'
  }
  return null
}

// Format plate with spaces: А 123 БВ 777
export function formatPlate(input: string): string {
  // Only allow Russian plate letters and digits
  const val = input.toUpperCase().replace(/[^АВЕКМНОРСТУХ0-9\s]/g, '')
  const noSpace = val.replace(/\s/g, '')
  if (noSpace.length <= 1) return val
  if (noSpace.length <= 4) return `${noSpace.slice(0, 1)} ${noSpace.slice(1)}`
  if (noSpace.length <= 6) return `${noSpace.slice(0, 1)} ${noSpace.slice(1, 4)} ${noSpace.slice(4)}`
  return `${noSpace.slice(0, 1)} ${noSpace.slice(1, 4)} ${noSpace.slice(4, 6)} ${noSpace.slice(6, 9)}`
}

// Validate name - any non-empty
export function validateName(name: string): string | null {
  if (!name || !name.trim()) return 'Введите имя'
  return null
}

// Validate car model - any non-empty
export function validateCarModel(model: string): string | null {
  if (!model || !model.trim()) return 'Введите модель авто'
  return null
}

export function getGreeting(): string {
  const hour = new Date().getHours()
  if (hour < 6) return 'Доброй ночи'
  if (hour < 12) return 'Доброе утро'
  if (hour < 18) return 'Добрый день'
  return 'Добрый вечер'
}
