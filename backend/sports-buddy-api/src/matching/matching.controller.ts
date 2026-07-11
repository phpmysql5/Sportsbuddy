import { Controller, Get, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthGuard } from '../auth/auth.guard';
import type { User } from '../core/domain.types';
import { MatchingService } from './matching.service';

@Controller('matching')
@UseGuards(AuthGuard)
export class MatchingController {
  constructor(private readonly matchingService: MatchingService) {}

  @Get('suggestions')
  getSuggestions(@CurrentUser() user: User) {
    return this.matchingService.getSuggestions(user);
  }
}
