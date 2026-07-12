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

function normalize(value: string | null | undefined): string {
  return (value ?? '').trim().toLowerCase();
}

@Injectable()
export class MatchingService {
  constructor(private readonly prisma: PrismaService) {}

  async getSuggestions(user: AuthenticatedUser): Promise<MatchSuggestion[]> {
    const current = await this.prisma.user.findUnique({
      where: { id: user.id },
    });
    if (!current) {
      return [];
    }

    const blocked = await this.prisma.userBlock.findMany({
      where: {
        OR: [{ blockerId: user.id }, { blockedId: user.id }],
      },
      select: {
        blockerId: true,
        blockedId: true,
      },
    });

    const excludedIds = new Set<string>([user.id]);
    for (const relation of blocked) {
      excludedIds.add(
        relation.blockerId === user.id
          ? relation.blockedId
          : relation.blockerId,
      );
    }

    const users = await this.prisma.user.findMany({
      where: {
        id: {
          notIn: Array.from(excludedIds),
        },
      },
    });

    const candidates = users
      .filter((candidate) => this.isCompatible(current, candidate))
      .map((candidate) => this.toSuggestion(current, candidate))
      .sort((a, b) => b.score - a.score);

    return candidates;
  }

  private isCompatible(current: User, candidate: User): boolean {
    const currentCity = normalize(current.city);
    const currentSport = normalize(current.sport);
    const candidateCity = normalize(candidate.city);
    const candidateSport = normalize(candidate.sport);

    return (
      currentCity.length > 0 &&
      currentSport.length > 0 &&
      !!current.skillLevel &&
      currentCity === candidateCity &&
      currentSport === candidateSport &&
      !!candidate.skillLevel &&
      Math.abs(
        skillScore[current.skillLevel] - skillScore[candidate.skillLevel],
      ) <= 1
    );
  }

  private toSuggestion(current: User, candidate: User): MatchSuggestion {
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
