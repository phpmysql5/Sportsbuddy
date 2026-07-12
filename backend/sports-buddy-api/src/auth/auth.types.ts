import { SkillLevel } from '@prisma/client';

export interface AuthenticatedUser {
  id: string;
  email: string;
  name: string;
  city: string | null;
  sport: string | null;
  sports: string[];
  skillLevel: SkillLevel | null;
  availabilityDays: string[];
}

export interface AccessTokenPayload {
  sub: string;
  email: string;
}
