import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { CreateSessionPlanDto } from './dto/create-session-plan.dto';
import { UpdateSessionStatusDto } from './dto/update-session-status.dto';
import { SessionsService } from './sessions.service';

@Controller('sessions/plans')
@UseGuards(AuthGuard)
export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  @Post()
  async create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateSessionPlanDto,
  ) {
    return this.sessionsService.createPlan(user, dto);
  }

  @Get('mine')
  async mine(@CurrentUser() user: AuthenticatedUser) {
    return this.sessionsService.myPlans(user);
  }

  @Get('discover')
  async discover(@CurrentUser() user: AuthenticatedUser) {
    return this.sessionsService.discoverPlans(user);
  }

  @Post(':planId/join')
  async join(
    @CurrentUser() user: AuthenticatedUser,
    @Param('planId') planId: string,
  ) {
    return this.sessionsService.joinPlan(user, planId);
  }

  @Delete(':planId/join')
  async leave(
    @CurrentUser() user: AuthenticatedUser,
    @Param('planId') planId: string,
  ) {
    return this.sessionsService.leavePlan(user, planId);
  }

  @Patch(':planId/status')
  async updateStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Param('planId') planId: string,
    @Body() dto: UpdateSessionStatusDto,
  ) {
    return this.sessionsService.updateStatus(user, planId, dto.status);
  }
}
