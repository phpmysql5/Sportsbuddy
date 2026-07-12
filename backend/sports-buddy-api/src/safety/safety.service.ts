import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthenticatedUser } from '../auth/auth.types';
import { toPublicUser } from '../common/user.mapper';
import { PrismaService } from '../database/prisma.service';
import type { ReportUserDto } from './dto/report-user.dto';

@Injectable()
export class SafetyService {
  constructor(private readonly prisma: PrismaService) {}

  async blockUser(user: AuthenticatedUser, targetUserId: string) {
    if (targetUserId === user.id) {
      throw new BadRequestException('You cannot block yourself');
    }

    const target = await this.prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true },
    });

    if (!target) {
      throw new NotFoundException('User not found');
    }

    try {
      await this.prisma.$transaction([
        this.prisma.userBlock.create({
          data: {
            blockerId: user.id,
            blockedId: targetUserId,
          },
        }),
        this.prisma.connectionRequest.deleteMany({
          where: {
            OR: [
              {
                senderId: user.id,
                receiverId: targetUserId,
              },
              {
                senderId: targetUserId,
                receiverId: user.id,
              },
            ],
          },
        }),
      ]);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new BadRequestException('User is already blocked');
      }
      throw error;
    }

    return { success: true };
  }

  async unblockUser(user: AuthenticatedUser, targetUserId: string) {
    const result = await this.prisma.userBlock.deleteMany({
      where: {
        blockerId: user.id,
        blockedId: targetUserId,
      },
    });

    if (result.count === 0) {
      throw new NotFoundException('Blocked user not found');
    }

    return { success: true };
  }

  async blockedUsers(user: AuthenticatedUser) {
    const rows = await this.prisma.userBlock.findMany({
      where: { blockerId: user.id },
      include: { blocked: true },
      orderBy: { createdAt: 'desc' },
    });

    return rows.map((row) => ({
      ...toPublicUser(row.blocked),
      blockedAt: row.createdAt,
    }));
  }

  async reportUser(user: AuthenticatedUser, dto: ReportUserDto) {
    if (dto.userId === user.id) {
      throw new BadRequestException('You cannot report yourself');
    }

    const target = await this.prisma.user.findUnique({
      where: { id: dto.userId },
      select: { id: true },
    });

    if (!target) {
      throw new NotFoundException('User not found');
    }

    const report = await this.prisma.userReport.create({
      data: {
        reporterId: user.id,
        reportedId: dto.userId,
        reason: dto.reason,
        details: dto.details?.trim() || null,
      },
      select: { id: true },
    });

    return {
      success: true,
      reportId: report.id,
    };
  }
}
