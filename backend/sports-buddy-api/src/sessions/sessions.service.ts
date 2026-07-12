import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { SessionPlanStatus } from '@prisma/client';
import type { AuthenticatedUser } from '../auth/auth.types';
import { toPublicUser } from '../common/user.mapper';
import { PrismaService } from '../database/prisma.service';
import type { CreateSessionPlanDto } from './dto/create-session-plan.dto';

@Injectable()
export class SessionsService {
  constructor(private readonly prisma: PrismaService) {}

  private async connectedBuddyIds(userId: string): Promise<Set<string>> {
    const accepted = await this.prisma.connectionRequest.findMany({
      where: {
        status: 'accepted',
        OR: [{ senderId: userId }, { receiverId: userId }],
      },
      select: {
        senderId: true,
        receiverId: true,
      },
    });

    return new Set(
      accepted.map((row) =>
        row.senderId === userId ? row.receiverId : row.senderId,
      ),
    );
  }

  private serializePlan(
    plan: {
      id: string;
      scheduledAt: Date;
      area: string;
      sport: string;
      skillLevel: 'beginner' | 'intermediate' | 'advanced';
      maxPlayers: number;
      status: SessionPlanStatus;
      createdAt: Date;
      updatedAt: Date;
      creatorId: string;
      creator: {
        id: string;
        email: string;
        name: string;
        city: string | null;
        sport: string | null;
        sports: string[];
        skillLevel: 'beginner' | 'intermediate' | 'advanced' | null;
        availabilityDays: string[];
        passwordHash: string;
        refreshTokenHash: string | null;
        createdAt: Date;
        updatedAt: Date;
      };
      participants: Array<{ userId: string }>;
    },
    currentUserId: string,
  ) {
    const participantsCount = plan.participants.length + 1;
    const joined =
      plan.creatorId === currentUserId ||
      plan.participants.some((entry) => entry.userId === currentUserId);

    return {
      id: plan.id,
      scheduledAt: plan.scheduledAt,
      area: plan.area,
      sport: plan.sport,
      skillLevel: plan.skillLevel,
      maxPlayers: plan.maxPlayers,
      status: plan.status,
      participantsCount,
      joined,
      creator: toPublicUser(plan.creator),
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
    };
  }

  async createPlan(user: AuthenticatedUser, dto: CreateSessionPlanDto) {
    const scheduledAt = new Date(dto.scheduledAt);
    if (Number.isNaN(scheduledAt.getTime())) {
      throw new BadRequestException('Invalid scheduled time');
    }

    const created = await this.prisma.sessionPlan.create({
      data: {
        creatorId: user.id,
        scheduledAt,
        area: dto.area.trim(),
        sport: dto.sport.trim(),
        skillLevel: dto.skillLevel,
        maxPlayers: dto.maxPlayers,
      },
      include: {
        creator: true,
        participants: {
          select: { userId: true },
        },
      },
    });

    return this.serializePlan(created, user.id);
  }

  async myPlans(user: AuthenticatedUser) {
    const plans = await this.prisma.sessionPlan.findMany({
      where: {
        OR: [
          { creatorId: user.id },
          { participants: { some: { userId: user.id } } },
        ],
      },
      include: {
        creator: true,
        participants: {
          select: { userId: true },
        },
      },
      orderBy: [{ scheduledAt: 'asc' }, { createdAt: 'asc' }],
    });

    return plans.map((plan) => this.serializePlan(plan, user.id));
  }

  async discoverPlans(user: AuthenticatedUser) {
    const buddyIds = await this.connectedBuddyIds(user.id);
    if (buddyIds.size === 0) {
      return [];
    }

    const plans = await this.prisma.sessionPlan.findMany({
      where: {
        creatorId: { in: Array.from(buddyIds) },
        status: 'open',
        participants: {
          none: { userId: user.id },
        },
      },
      include: {
        creator: true,
        participants: {
          select: { userId: true },
        },
      },
      orderBy: [{ scheduledAt: 'asc' }, { createdAt: 'asc' }],
    });

    return plans
      .filter((plan) => plan.participants.length + 1 < plan.maxPlayers)
      .map((plan) => this.serializePlan(plan, user.id));
  }

  async joinPlan(user: AuthenticatedUser, planId: string) {
    const plan = await this.prisma.sessionPlan.findUnique({
      where: { id: planId },
      include: {
        creator: true,
        participants: {
          select: { userId: true },
        },
      },
    });

    if (!plan) {
      throw new NotFoundException('Session plan not found');
    }

    if (plan.creatorId === user.id) {
      throw new BadRequestException('Creator is already part of the session');
    }

    if (plan.status !== 'open') {
      throw new BadRequestException('Only open session plans can be joined');
    }

    const buddyIds = await this.connectedBuddyIds(user.id);
    if (!buddyIds.has(plan.creatorId)) {
      throw new BadRequestException('You can only join connected buddy plans');
    }

    if (plan.participants.some((entry) => entry.userId === user.id)) {
      throw new BadRequestException('You already joined this session plan');
    }

    if (plan.participants.length + 1 >= plan.maxPlayers) {
      throw new BadRequestException('Session plan is already full');
    }

    await this.prisma.sessionPlanParticipant.create({
      data: {
        sessionId: plan.id,
        userId: user.id,
      },
    });

    const updated = await this.prisma.sessionPlan.findUniqueOrThrow({
      where: { id: plan.id },
      include: {
        creator: true,
        participants: {
          select: { userId: true },
        },
      },
    });

    return this.serializePlan(updated, user.id);
  }

  async leavePlan(user: AuthenticatedUser, planId: string) {
    const plan = await this.prisma.sessionPlan.findUnique({
      where: { id: planId },
      select: { id: true, creatorId: true },
    });

    if (!plan) {
      throw new NotFoundException('Session plan not found');
    }

    if (plan.creatorId === user.id) {
      throw new BadRequestException('Creator cannot leave own session plan');
    }

    const result = await this.prisma.sessionPlanParticipant.deleteMany({
      where: {
        sessionId: plan.id,
        userId: user.id,
      },
    });

    if (result.count === 0) {
      throw new NotFoundException('Session join not found');
    }

    return { success: true };
  }

  async updateStatus(
    user: AuthenticatedUser,
    planId: string,
    status: SessionPlanStatus,
  ) {
    const plan = await this.prisma.sessionPlan.findUnique({
      where: { id: planId },
      include: {
        creator: true,
        participants: {
          select: { userId: true },
        },
      },
    });

    if (!plan) {
      throw new NotFoundException('Session plan not found');
    }

    if (plan.creatorId !== user.id) {
      throw new BadRequestException('Only creator can update session status');
    }

    const updated = await this.prisma.sessionPlan.update({
      where: { id: plan.id },
      data: { status },
      include: {
        creator: true,
        participants: {
          select: { userId: true },
        },
      },
    });

    return this.serializePlan(updated, user.id);
  }
}
