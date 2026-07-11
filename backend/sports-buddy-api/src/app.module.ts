import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { PrismaModule } from './database/prisma.module';
import { MatchingModule } from './matching/matching.module';
import { ProfileModule } from './profile/profile.module';
import { AppController } from './app.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (env) => {
        if (env.NODE_ENV === 'test') {
          return {
            ...env,
            DATABASE_URL:
              env.DATABASE_URL ??
              'postgresql://sportsbuddy:sportsbuddy@localhost:5432/sportsbuddy?schema=public',
            JWT_ACCESS_SECRET: env.JWT_ACCESS_SECRET ?? 'test-access-secret',
            JWT_REFRESH_SECRET: env.JWT_REFRESH_SECRET ?? 'test-refresh-secret',
          };
        }

        const required = [
          'DATABASE_URL',
          'JWT_ACCESS_SECRET',
          'JWT_REFRESH_SECRET',
        ];

        for (const key of required) {
          if (!env[key]) {
            throw new Error(`Missing required environment variable: ${key}`);
          }
        }

        return env;
      },
    }),
    PrismaModule,
    AuthModule,
    ProfileModule,
    MatchingModule,
  ],
  controllers: [AppController],
  providers: [],
})
export class AppModule {}
