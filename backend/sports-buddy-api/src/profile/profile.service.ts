import { BadRequestException, Injectable } from '@nestjs/common';
import type { AuthenticatedUser } from '../auth/auth.types';
import { toPublicUser } from '../common/user.mapper';
import { PrismaService } from '../database/prisma.service';
import { UpsertProfileDto } from './dto/upsert-profile.dto';

@Injectable()
export class ProfileService {
  constructor(private readonly prisma: PrismaService) {}

  private normalizeSports(dto: UpsertProfileDto): string[] {
    const normalized = (dto.sports ?? [])
      .map((sport) => sport.trim())
      .filter((sport) => sport.length >= 2);

    if (normalized.length > 0) {
      return Array.from(new Set(normalized));
    }

    const legacySport = dto.sport?.trim() ?? '';
    if (legacySport.length >= 2) {
      return [legacySport];
    }

    throw new BadRequestException('At least one sport is required');
  }

  async getProfile(user: AuthenticatedUser) {
    const dbUser = await this.prisma.user.findUniqueOrThrow({
      where: { id: user.id },
    });
    return toPublicUser(dbUser);
  }

  async upsertProfile(user: AuthenticatedUser, dto: UpsertProfileDto) {
    const sports = this.normalizeSports(dto);

    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        city: dto.city,
        sport: sports[0],
        sports,
        skillLevel: dto.skillLevel,
        availabilityDays: dto.availabilityDays ?? [],
      },
    });

    return toPublicUser(updated);
  }
}
