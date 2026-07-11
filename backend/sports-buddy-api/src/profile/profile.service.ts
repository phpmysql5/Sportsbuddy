import { Injectable } from '@nestjs/common';
import { User } from '../core/domain.types';
import { MemoryStoreService } from '../core/memory-store.service';
import { UpsertProfileDto } from './dto/upsert-profile.dto';

@Injectable()
export class ProfileService {
  constructor(private readonly store: MemoryStoreService) {}

  getProfile(user: User) {
    return this.store.toPublicUser(user);
  }

  upsertProfile(user: User, dto: UpsertProfileDto) {
    const updated = this.store.updateProfile(user.id, {
      city: dto.city,
      sport: dto.sport,
      skillLevel: dto.skillLevel,
      availabilityDays: dto.availabilityDays,
    });

    return this.store.toPublicUser(updated);
  }
}
