import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { PrismaModule } from './database/prisma.module';
import { MatchingModule } from './matching/matching.module';
import { ProfileModule } from './profile/profile.module';
import { AppController } from './app.controller';

function readEnvString(
  env: Record<string, unknown>,
  key: string,
): string | undefined {
  const value = env[key];
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

function readNodeEnv(): string {
  return process.env.NODE_ENV?.trim().toLowerCase() ?? 'development';
}

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (env: Record<string, unknown>) => {
        const nodeEnv = readEnvString(env, 'NODE_ENV');

        if (nodeEnv === 'test') {
          return {
            ...env,
            DATABASE_URL:
              readEnvString(env, 'DATABASE_URL') ??
              'postgresql://sportsbuddy:sportsbuddy@localhost:5432/sportsbuddy?schema=public',
            JWT_ACCESS_SECRET:
              readEnvString(env, 'JWT_ACCESS_SECRET') ?? 'test-access-secret',
            JWT_REFRESH_SECRET:
              readEnvString(env, 'JWT_REFRESH_SECRET') ?? 'test-refresh-secret',
          };
        }

        const required = [
          'DATABASE_URL',
          'JWT_ACCESS_SECRET',
          'JWT_REFRESH_SECRET',
        ];

        for (const key of required) {
          if (!readEnvString(env, key)) {
            throw new Error(`Missing required environment variable: ${key}`);
          }
        }

        return env;
      },
    }),
    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: readNodeEnv() === 'test' ? 10_000 : 60,
      },
    ]),
    PrismaModule,
    AuthModule,
    ProfileModule,
    MatchingModule,
  ],
  controllers: [AppController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
