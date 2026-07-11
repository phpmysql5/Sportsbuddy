import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PublicUser, SkillLevel, User } from './domain.types';

@Injectable()
export class MemoryStoreService {
  private readonly users: User[] = [];
  private readonly sessions = new Map<string, string>();

  createUser(input: { email: string; password: string; name: string }): User {
    const user: User = {
      id: randomUUID(),
      email: input.email.toLowerCase(),
      password: input.password,
      name: input.name,
    };
    this.users.push(user);
    return user;
  }

  findUserByEmail(email: string): User | undefined {
    return this.users.find((u) => u.email === email.toLowerCase());
  }

  findUserById(id: string): User | undefined {
    return this.users.find((u) => u.id === id);
  }

  createSession(userId: string): string {
    const token = randomUUID();
    this.sessions.set(token, userId);
    return token;
  }

  getUserByToken(token: string): User | undefined {
    const userId = this.sessions.get(token);
    if (!userId) {
      return undefined;
    }
    return this.findUserById(userId);
  }

  toPublicUser(user: User): PublicUser {
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      city: user.city,
      sport: user.sport,
      skillLevel: user.skillLevel,
      availabilityDays: user.availabilityDays,
    };
  }

  updateProfile(
    userId: string,
    profile: {
      city: string;
      sport: string;
      skillLevel: SkillLevel;
      availabilityDays?: string[];
    },
  ): User {
    const user = this.findUserById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    user.city = profile.city;
    user.sport = profile.sport;
    user.skillLevel = profile.skillLevel;
    user.availabilityDays = profile.availabilityDays ?? [];

    return user;
  }

  listUsers(): User[] {
    return this.users;
  }
}
