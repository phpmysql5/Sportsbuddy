import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { SendMessageDto } from './dto/send-message.dto';
import { ChatService } from './chat.service';

@Controller('chat')
@UseGuards(AuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post('buddies/:buddyId/messages')
  async sendMessage(
    @CurrentUser() user: AuthenticatedUser,
    @Param('buddyId') buddyId: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.chatService.sendMessage(user, buddyId, dto.content);
  }

  @Get('buddies/:buddyId/messages')
  async messages(
    @CurrentUser() user: AuthenticatedUser,
    @Param('buddyId') buddyId: string,
    @Query('limit', new ParseIntPipe({ optional: true })) limit?: number,
  ) {
    return this.chatService.conversation(user, buddyId, limit ?? 20);
  }
}
