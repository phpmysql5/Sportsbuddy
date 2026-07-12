import { IsDateString, IsIn, IsInt, IsString, Max, Min, MinLength } from 'class-validator';
import { SkillLevel } from '@prisma/client';
import { SUPPORTED_CITIES } from '../../common/supported-cities';
import { SUPPORTED_SPORTS } from '../../common/supported-sports';

const SKILL_LEVELS: SkillLevel[] = ['beginner', 'intermediate', 'advanced'];

export class CreateSessionPlanDto {
  @IsDateString()
  scheduledAt: string;

  @IsString()
  @MinLength(2)
  @IsIn([...SUPPORTED_CITIES], {
    message: 'Area must be one of the supported cities',
  })
  area: string;

  @IsString()
  @MinLength(2)
  @IsIn([...SUPPORTED_SPORTS], {
    message: 'Sport must be one of the supported sports',
  })
  sport: string;

  @IsString()
  @IsIn(SKILL_LEVELS)
  skillLevel: SkillLevel;

  @IsInt()
  @Min(2)
  @Max(30)
  maxPlayers: number;
}
