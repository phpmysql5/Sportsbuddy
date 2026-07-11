import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import type { User } from '../core/domain.types';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { UpsertProfileDto } from './dto/upsert-profile.dto';
import { ProfileService } from './profile.service';

@Controller('profile')
@UseGuards(AuthGuard)
export class ProfileController {
  constructor(private readonly profileService: ProfileService) {}

  @Get()
  getProfile(@CurrentUser() user: User) {
    return this.profileService.getProfile(user);
  }

  @Put()
  upsert(@CurrentUser() user: User, @Body() dto: UpsertProfileDto) {
    return this.profileService.upsertProfile(user, dto);
  }
}
