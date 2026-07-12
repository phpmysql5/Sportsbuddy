import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthGuard } from '../auth/auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { BlockUserDto } from './dto/block-user.dto';
import { ReportUserDto } from './dto/report-user.dto';
import { SafetyService } from './safety.service';

const reportLimit = process.env.NODE_ENV === 'test' ? 3 : 3;

@Controller('safety')
@UseGuards(AuthGuard)
export class SafetyController {
  constructor(private readonly safetyService: SafetyService) {}

  @Post('blocks')
  async blockUser(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: BlockUserDto,
  ) {
    return this.safetyService.blockUser(user, dto.userId);
  }

  @Delete('blocks/:userId')
  async unblockUser(
    @CurrentUser() user: AuthenticatedUser,
    @Param('userId') userId: string,
  ) {
    return this.safetyService.unblockUser(user, userId);
  }

  @Get('blocks')
  async blockedUsers(@CurrentUser() user: AuthenticatedUser) {
    return this.safetyService.blockedUsers(user);
  }

  @Post('reports')
  @Throttle({ default: { limit: reportLimit, ttl: 60_000 } })
  async reportUser(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: ReportUserDto,
  ) {
    return this.safetyService.reportUser(user, dto);
  }
}
