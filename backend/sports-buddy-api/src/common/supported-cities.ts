export const SUPPORTED_CITIES = [
  'Mangalore',
  'Bengaluru',
  'Mumbai',
  'Delhi',
  'Hyderabad',
  'Chennai',
] as const;

export type SupportedCity = (typeof SUPPORTED_CITIES)[number];