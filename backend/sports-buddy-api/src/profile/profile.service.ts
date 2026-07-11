import { Injectable } from '@nestjs/common';
import type { AuthenticatedUser } from '../auth/auth.types';
import { toPublicUser } from '../common/user.mapper';
import { PrismaService } from '../database/prisma.service';
import { UpsertProfileDto } from './dto/upsert-profile.dto';

@Injectable()
export class ProfileService {
  constructor(private readonly prisma: PrismaService) {}

  async getProfile(user: AuthenticatedUser) {
    const dbUser = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
    });
    return toPublicUser(dbUser);
  }

  async upsertProfile(user: AuthenticatedUser, dto: UpsertProfileDto) {
    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        city: dto.city,
        sport: dto.sport,
        skillLevel: dto.skillLevel,
        availabilityDays: dto.availabilityDays ?? [],
      },
    });

    return toPublicUser(updated);
  }
}
