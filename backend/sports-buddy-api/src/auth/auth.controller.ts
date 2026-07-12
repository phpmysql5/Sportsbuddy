import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthGuard } from './auth.guard';
import { AuthService } from './auth.service';
import type { AuthenticatedUser } from './auth.types';
import { CurrentUser } from './current-user.decorator';
import { GoogleAuthDto } from './dto/google-auth.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';

const isTestEnv = process.env.NODE_ENV === 'test';
const registerLimit = isTestEnv ? 10_000 : 5;
const loginLimit = isTestEnv ? 10_000 : 8;
const googleLimit = isTestEnv ? 10_000 : 8;
const refreshLimit = isTestEnv ? 10_000 : 20;

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @Throttle({ default: { limit: registerLimit, ttl: 60_000 } })
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  @Throttle({ default: { limit: loginLimit, ttl: 60_000 } })
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('google')
  @Throttle({ default: { limit: googleLimit, ttl: 60_000 } })
  async google(@Body() dto: GoogleAuthDto) {
    return this.authService.google(dto);
  }

  @Post('refresh')
  @Throttle({ default: { limit: refreshLimit, ttl: 60_000 } })
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto);
  }

  @Get('me')
  @UseGuards(AuthGuard)
  me(@CurrentUser() user: AuthenticatedUser) {
    return this.authService.getPublicUser(user);
  }

  @Post('logout')
  @UseGuards(AuthGuard)
  async logout(@CurrentUser() user: AuthenticatedUser) {
    return this.authService.logout(user.id);
  }
}
