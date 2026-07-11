import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import type { SkillLevel } from '../../core/domain.types';

const SKILL_LEVELS: SkillLevel[] = ['beginner', 'intermediate', 'advanced'];

export class UpsertProfileDto {
  @IsString()
  @MinLength(2)
  city: string;

  @IsString()
  @MinLength(2)
  sport: string;

  @IsString()
  @IsIn(SKILL_LEVELS)
  skillLevel: SkillLevel;

  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @ArrayMaxSize(7)
  @IsString({ each: true })
  availabilityDays?: string[];
}
