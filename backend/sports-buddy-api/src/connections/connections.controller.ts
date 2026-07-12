import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { ConnectionsService } from './connections.service';
import { RespondRequestDto } from './dto/respond-request.dto';
import { SendRequestDto } from './dto/send-request.dto';

@Controller('connections')
@UseGuards(AuthGuard)
export class ConnectionsController {
  constructor(private readonly connectionsService: ConnectionsService) {}

  @Post('requests')
  async sendRequest(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: SendRequestDto,
  ) {
    return this.connectionsService.sendRequest(user, dto);
  }

  @Get('requests/incoming')
  async incoming(@CurrentUser() user: AuthenticatedUser) {
    return this.connectionsService.incomingRequests(user);
  }

  @Get('requests/outgoing')
  async outgoing(@CurrentUser() user: AuthenticatedUser) {
    return this.connectionsService.outgoingRequests(user);
  }

  @Post('requests/:requestId/respond')
  async respond(
    @CurrentUser() user: AuthenticatedUser,
    @Param('requestId') requestId: string,
    @Body() dto: RespondRequestDto,
  ) {
    return this.connectionsService.respond(user, requestId, dto);
  }

  @Get('buddies')
  async buddies(@CurrentUser() user: AuthenticatedUser) {
    return this.connectionsService.buddies(user);
  }
}
