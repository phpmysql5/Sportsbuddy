import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { AuthenticatedUser } from '../auth/auth.types';
import { toPublicUser } from '../common/user.mapper';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class ChatService {
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

  private async areConnected(userAId: string, userBId: string) {
    const connection = await this.prisma.connectionRequest.findFirst({
      where: {
        status: 'accepted',
        OR: [
          { senderId: userAId, receiverId: userBId },
          { senderId: userBId, receiverId: userAId },
        ],
      },
      select: { id: true },
    });

    return !!connection;
  }

  async sendMessage(user: AuthenticatedUser, buddyId: string, content: string) {
    if (buddyId === user.id) {
      throw new BadRequestException('You cannot message yourself');
    }

    const buddy = await this.prisma.user.findUnique({
      where: { id: buddyId },
      select: { id: true },
    });

    if (!buddy) {
      throw new NotFoundException('Buddy not found');
    }

    const trimmedContent = content.trim();
    if (trimmedContent.length === 0) {
      throw new BadRequestException('Message cannot be empty');
    }

    if (await this.hasBlockBetween(user.id, buddyId)) {
      throw new BadRequestException('Cannot message blocked user');
    }

    if (!(await this.areConnected(user.id, buddyId))) {
      throw new BadRequestException('You can only message connected buddies');
    }

    const message = await this.prisma.buddyMessage.create({
      data: {
        senderId: user.id,
        receiverId: buddyId,
        content: trimmedContent,
      },
      include: {
        sender: true,
        receiver: true,
      },
    });

    return {
      id: message.id,
      content: message.content,
      sender: toPublicUser(message.sender),
      receiver: toPublicUser(message.receiver),
      createdAt: message.createdAt,
    };
  }

  async conversation(user: AuthenticatedUser, buddyId: string, limit: number) {
    if (buddyId === user.id) {
      throw new BadRequestException('Invalid buddy');
    }

    const safeLimit = Math.min(Math.max(limit, 1), 50);

    if (await this.hasBlockBetween(user.id, buddyId)) {
      throw new BadRequestException('Cannot view messages with blocked user');
    }

    if (!(await this.areConnected(user.id, buddyId))) {
      throw new BadRequestException(
        'You can only view connected buddy messages',
      );
    }

    const messages = await this.prisma.buddyMessage.findMany({
      where: {
        OR: [
          { senderId: user.id, receiverId: buddyId },
          { senderId: buddyId, receiverId: user.id },
        ],
      },
      include: {
        sender: true,
        receiver: true,
      },
      orderBy: { createdAt: 'desc' },
      take: safeLimit,
    });

    return messages.reverse().map((message) => ({
      id: message.id,
      content: message.content,
      sender: toPublicUser(message.sender),
      receiver: toPublicUser(message.receiver),
      createdAt: message.createdAt,
    }));
  }
}
