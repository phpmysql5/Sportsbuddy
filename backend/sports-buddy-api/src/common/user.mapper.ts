import { SkillLevel, User } from '@prisma/client';

export interface PublicUser {
  id: string;
  email: string;
  name: string;
  city: string | null;
  sport: string | null;
  sports: string[];
  skillLevel: SkillLevel | null;
  availabilityDays: string[];
}

export interface MatchSuggestion {
  user: PublicUser;
  score: number;
  reasons: string[];
}

export function toPublicUser(user: User): PublicUser {
  const sports =
    user.sports.length > 0 ? user.sports : user.sport ? [user.sport] : [];

  return {
    id: user.id,
    email: user.email,
    name: user.name,
    city: user.city,
    sport: sports[0] ?? null,
    sports,
    skillLevel: user.skillLevel,
    availabilityDays: user.availabilityDays,
  };
}
