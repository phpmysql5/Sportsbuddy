export const SUPPORTED_SPORTS = [
  'Tennis',
  'Badminton',
  'Cricket',
  'Football',
  'Basketball',
  'Pickleball',
] as const;

export type SupportedSport = (typeof SUPPORTED_SPORTS)[number];