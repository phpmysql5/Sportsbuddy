import { Controller, Get, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthGuard } from '../auth/auth.guard';
import type { AuthenticatedUser } from '../auth/auth.types';
import { MatchingService } from './matching.service';

@Controller('matching')
@UseGuards(AuthGuard)
export class MatchingController {
  constructor(private readonly matchingService: MatchingService) {}

  @Get('suggestions')
  async getSuggestions(@CurrentUser() user: AuthenticatedUser) {
    return this.matchingService.getSuggestions(user);
  }
}
