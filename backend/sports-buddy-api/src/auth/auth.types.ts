import { SkillLevel } from '@prisma/client';

export interface AuthenticatedUser {
  id: string;
  email: string;
  name: string;
  city: string | null;
  sport: string | null;
  skillLevel: SkillLevel | null;
  availabilityDays: string[];
}

export interface AccessTokenPayload {
  sub: string;
  email: string;
}
