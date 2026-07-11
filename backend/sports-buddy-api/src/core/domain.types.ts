export type SkillLevel = 'beginner' | 'intermediate' | 'advanced';

export interface User {
  id: string;
  email: string;
  password: string;
  name: string;
  city?: string;
  sport?: string;
  skillLevel?: SkillLevel;
  availabilityDays?: string[];
}

export interface PublicUser {
  id: string;
  email: string;
  name: string;
  city?: string;
  sport?: string;
  skillLevel?: SkillLevel;
  availabilityDays?: string[];
}

export interface MatchSuggestion {
  user: PublicUser;
  score: number;
  reasons: string[];
}
