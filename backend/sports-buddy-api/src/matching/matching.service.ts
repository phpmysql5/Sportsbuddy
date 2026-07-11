import { Injectable } from '@nestjs/common';
import { SkillLevel, User } from '@prisma/client';
import type { AuthenticatedUser } from '../auth/auth.types';
import { MatchSuggestion, toPublicUser } from '../common/user.mapper';
import { PrismaService } from '../database/prisma.service';

const skillScore: Record<SkillLevel, number> = {
  beginner: 1,
  intermediate: 2,
  advanced: 3,
};

@Injectable()
export class MatchingService {
  constructor(private readonly prisma: PrismaService) {}

  async getSuggestions(user: AuthenticatedUser): Promise<MatchSuggestion[]> {
    const users = await this.prisma.user.findMany();

    const current = users.find((candidate) => candidate.id === user.id);
    if (!current) {
      return [];
    }

    const candidates = users
      .filter((candidate) => candidate.id !== user.id)
      .filter((candidate) => this.isCompatible(user, candidate))
      .map((candidate) => this.toSuggestion(user, candidate))
      .sort((a, b) => b.score - a.score);

    return candidates;
  }

  private isCompatible(current: AuthenticatedUser, candidate: User): boolean {
    return (
      !!current.city &&
      !!current.sport &&
      !!current.skillLevel &&
      current.city === candidate.city &&
      current.sport === candidate.sport &&
      !!candidate.skillLevel &&
      Math.abs(
        skillScore[current.skillLevel] - skillScore[candidate.skillLevel],
      ) <= 1
    );
  }

  private toSuggestion(
    current: AuthenticatedUser,
    candidate: User,
  ): MatchSuggestion {
    const reasons = ['Same city', 'Same sport'];

    if (current.skillLevel === candidate.skillLevel) {
      reasons.push('Same skill level');
    }

    const currentDays = new Set(current.availabilityDays ?? []);
    const overlap = (candidate.availabilityDays ?? []).filter((d) =>
      currentDays.has(d),
    );

    if (overlap.length > 0) {
      reasons.push('Shared availability');
    }

    const score = reasons.length;
    return {
      user: toPublicUser(candidate),
      score,
      reasons,
    };
  }
}
