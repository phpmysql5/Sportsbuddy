import {
  ArrayMinSize,
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import { SkillLevel } from '@prisma/client';
import { SUPPORTED_CITIES } from '../../common/supported-cities';
import { SUPPORTED_SPORTS } from '../../common/supported-sports';

const SKILL_LEVELS: SkillLevel[] = ['beginner', 'intermediate', 'advanced'];

export class UpsertProfileDto {
  @IsString()
  @MinLength(2)
  @IsIn([...SUPPORTED_CITIES], {
    message: 'City must be one of the supported cities',
  })
  city: string;

  @IsString()
  @MinLength(2)
  @IsOptional()
  @IsIn([...SUPPORTED_SPORTS], {
    message: 'Sport must be one of the supported sports',
  })
  sport?: string;

  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @ArrayMinSize(1)
  @ArrayMaxSize(10)
  @IsString({ each: true })
  @MinLength(2, { each: true })
  @IsIn([...SUPPORTED_SPORTS], {
    each: true,
    message: 'Each sport must be one of the supported sports',
  })
  sports?: string[];

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
