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

    return requests.map((request) => ({
      id: request.id,
      status: request.status,
      sender: toPublicUser(request.sender),
      createdAt: request.createdAt,
    }));
  }

  async outgoingRequests(user: AuthenticatedUser) {
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

    return requests.map((request) => ({
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

    return requests.map((request) => {
      const buddy =
        request.senderId === user.id ? request.receiver : request.sender;
      return toPublicUser(buddy);
    });
  }
}
