import { SkillLevel, User } from '@prisma/client';

export interface PublicUser {
  id: string;
  email: string;
  name: string;
  city: string | null;
  sport: string | null;
  skillLevel: SkillLevel | null;
  availabilityDays: string[];
}

export interface MatchSuggestion {
  user: PublicUser;
  score: number;
  reasons: string[];
}

export function toPublicUser(user: User): PublicUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    city: user.city,
    sport: user.sport,
    skillLevel: user.skillLevel,
    availabilityDays: user.availabilityDays,
  };
}
