import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConnectionRequestStatus } from '@prisma/client';
import type { AuthenticatedUser } from '../auth/auth.types';
import { toPublicUser } from '../common/user.mapper';
import { PrismaService } from '../database/prisma.service';
import type { RespondRequestDto } from './dto/respond-request.dto';
import type { SendRequestDto } from './dto/send-request.dto';

@Injectable()
export class ConnectionsService {
  constructor(private readonly prisma: PrismaService) {}

  private async hasBlockBetween(userAId: string, userBId: string) {
    const block = await this.prisma.userBlock.findFirst({
      where: {
        OR: [
          { blockerId: userAId, blockedId: userBId },
          { blockerId: userBId, blockedId: userAId },
        ],
      },
      select: { id: true },
    });

    return !!block;
  }

  private async blockedCounterpartIds(userId: string): Promise<Set<string>> {
    const relations = await this.prisma.userBlock.findMany({
      where: {
        OR: [{ blockerId: userId }, { blockedId: userId }],
      },
      select: {
        blockerId: true,
        blockedId: true,
      },
    });

    return new Set(
      relations.map((relation) =>
        relation.blockerId === userId ? relation.blockedId : relation.blockerId,
      ),
    );
  }

  async sendRequest(user: AuthenticatedUser, dto: SendRequestDto) {
    if (dto.receiverId === user.id) {
      throw new BadRequestException('You cannot send request to yourself');
    }

    const receiver = await this.prisma.user.findUnique({
      where: { id: dto.receiverId },
    });
    if (!receiver) {
      throw new NotFoundException('Receiver not found');
    }

    if (await this.hasBlockBetween(user.id, dto.receiverId)) {
      throw new BadRequestException('Cannot send request to blocked user');
    }

    const existing = await this.prisma.connectionRequest.findFirst({
      where: {
        OR: [
          { senderId: user.id, receiverId: dto.receiverId },
          { senderId: dto.receiverId, receiverId: user.id },
        ],
        status: { in: ['pending', 'accepted'] },
      },
    });

    if (existing) {
      if (existing.status === 'accepted') {
        throw new BadRequestException('You are already connected');
      }
      throw new BadRequestException('Connection request already exists');
    }

    const created = await this.prisma.connectionRequest.create({
      data: {
        senderId: user.id,
        receiverId: dto.receiverId,
      },
      include: {
        sender: true,
        receiver: true,
      },
    });

    return {
      id: created.id,
      status: created.status,
      sender: toPublicUser(created.sender),
      receiver: toPublicUser(created.receiver),
      createdAt: created.createdAt,
    };
  }

  async incomingRequests(user: AuthenticatedUser) {
    const blockedIds = await this.blockedCounterpartIds(user.id);

    const requests = await this.prisma.connectionRequest.findMany({
      where: {
        receiverId: user.id,
        status: 'pending',
      },
      include: {
        sender: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    return requests
      .filter((request) => !blockedIds.has(request.senderId))
      .map((request) => ({
        id: request.id,
        status: request.status,
        sender: toPublicUser(request.sender),
        createdAt: request.createdAt,
      }));
  }

  async outgoingRequests(user: AuthenticatedUser) {
    const blockedIds = await this.blockedCounterpartIds(user.id);

    const requests = await this.prisma.connectionRequest.findMany({
      where: {
        senderId: user.id,
        status: 'pending',
      },
      include: {
        receiver: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    return requests
      .filter((request) => !blockedIds.has(request.receiverId))
      .map((request) => ({
        id: request.id,
        status: request.status,
        receiver: toPublicUser(request.receiver),
        createdAt: request.createdAt,
      }));
  }

  async respond(
    user: AuthenticatedUser,
    requestId: string,
    dto: RespondRequestDto,
  ) {
    const request = await this.prisma.connectionRequest.findUnique({
      where: { id: requestId },
      include: {
        sender: true,
        receiver: true,
      },
    });

    if (!request || request.receiverId != user.id) {
      throw new NotFoundException('Request not found');
    }

    if (request.status !== 'pending') {
      throw new BadRequestException('Request already processed');
    }

    if (await this.hasBlockBetween(request.senderId, request.receiverId)) {
      throw new BadRequestException('Cannot respond to blocked user request');
    }

    const status: ConnectionRequestStatus =
      dto.action === 'accept' ? 'accepted' : 'rejected';

    const updated = await this.prisma.connectionRequest.update({
      where: { id: requestId },
      data: { status },
      include: {
        sender: true,
        receiver: true,
      },
    });

    return {
      id: updated.id,
      status: updated.status,
      sender: toPublicUser(updated.sender),
      receiver: toPublicUser(updated.receiver),
      updatedAt: updated.updatedAt,
    };
  }

  async buddies(user: AuthenticatedUser) {
    const blockedIds = await this.blockedCounterpartIds(user.id);

    const requests = await this.prisma.connectionRequest.findMany({
      where: {
        status: 'accepted',
        OR: [{ senderId: user.id }, { receiverId: user.id }],
      },
      include: {
        sender: true,
        receiver: true,
      },
      orderBy: { updatedAt: 'desc' },
    });

    return requests
      .filter((request) => {
        const buddyId =
          request.senderId === user.id ? request.receiverId : request.senderId;
        return !blockedIds.has(buddyId);
      })
      .map((request) => {
        const buddy =
          request.senderId === user.id ? request.receiver : request.sender;
        return toPublicUser(buddy);
      });
  }

  async cancelOutgoing(user: AuthenticatedUser, requestId: string) {
    const request = await this.prisma.connectionRequest.findUnique({
      where: { id: requestId },
    });

    if (!request || request.senderId !== user.id) {
      throw new NotFoundException('Request not found');
    }

    if (request.status !== 'pending') {
      throw new BadRequestException('Only pending requests can be cancelled');
    }

    await this.prisma.connectionRequest.delete({
      where: { id: requestId },
    });

    return { success: true };
  }

  async unfriend(user: AuthenticatedUser, buddyId: string) {
    if (buddyId === user.id) {
      throw new BadRequestException('You cannot remove yourself');
    }

    const existing = await this.prisma.connectionRequest.findFirst({
      where: {
        status: 'accepted',
        OR: [
          { senderId: user.id, receiverId: buddyId },
          { senderId: buddyId, receiverId: user.id },
        ],
      },
      select: { id: true },
    });

    if (!existing) {
      throw new NotFoundException('Connection not found');
    }

    await this.prisma.connectionRequest.delete({
      where: { id: existing.id },
    });

    return { success: true };
  }
}
