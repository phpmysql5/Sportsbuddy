import { Injectable } from '@nestjs/common';
import { MatchSuggestion, SkillLevel, User } from '../core/domain.types';
import { MemoryStoreService } from '../core/memory-store.service';

const skillScore: Record<SkillLevel, number> = {
  beginner: 1,
  intermediate: 2,
  advanced: 3,
};

@Injectable()
export class MatchingService {
  constructor(private readonly store: MemoryStoreService) {}

  getSuggestions(user: User): MatchSuggestion[] {
    const candidates = this.store
      .listUsers()
      .filter((candidate) => candidate.id !== user.id)
      .filter((candidate) => this.isCompatible(user, candidate))
      .map((candidate) => this.toSuggestion(user, candidate))
      .sort((a, b) => b.score - a.score);

    return candidates;
  }

  private isCompatible(current: User, candidate: User): boolean {
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
      user: this.store.toPublicUser(candidate),
      score,
      reasons,
    };
  }
}
