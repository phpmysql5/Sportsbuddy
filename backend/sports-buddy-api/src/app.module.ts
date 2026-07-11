import { Module } from '@nestjs/common';
import { AuthModule } from './auth/auth.module';
import { CoreModule } from './core/core.module';
import { MatchingModule } from './matching/matching.module';
import { ProfileModule } from './profile/profile.module';
import { AppController } from './app.controller';

@Module({
  imports: [CoreModule, AuthModule, ProfileModule, MatchingModule],
  controllers: [AppController],
  providers: [],
})
export class AppModule {}
