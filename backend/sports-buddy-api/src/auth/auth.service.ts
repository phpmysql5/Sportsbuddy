import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { MemoryStoreService } from '../core/memory-store.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { PublicUser, User } from '../core/domain.types';

@Injectable()
export class AuthService {
  constructor(private readonly store: MemoryStoreService) {}

  register(dto: RegisterDto): { accessToken: string; user: PublicUser } {
    const existing = this.store.findUserByEmail(dto.email);
    if (existing) {
      throw new BadRequestException('Email is already registered');
    }

    const user = this.store.createUser({
      email: dto.email,
      password: dto.password,
      name: dto.name,
    });

    const accessToken = this.store.createSession(user.id);
    return { accessToken, user: this.store.toPublicUser(user) };
  }

  login(dto: LoginDto): { accessToken: string; user: PublicUser } {
    const user = this.store.findUserByEmail(dto.email);
    if (!user || user.password !== dto.password) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const accessToken = this.store.createSession(user.id);
    return { accessToken, user: this.store.toPublicUser(user) };
  }

  getPublicUser(user: User): PublicUser {
    return this.store.toPublicUser(user);
  }

  resolveToken(token: string): User {
    const user = this.store.getUserByToken(token);
    if (!user) {
      throw new UnauthorizedException('Invalid or expired token');
    }
    return user;
  }
}
