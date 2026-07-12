import { IsIn, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

const REPORT_REASONS = [
  'harassment',
  'inappropriate_behavior',
  'fraud',
  'spam',
  'other',
] as const;

export type ReportReasonType = (typeof REPORT_REASONS)[number];

export class ReportUserDto {
  @IsUUID()
  userId: string;

  @IsString()
  @IsIn(REPORT_REASONS)
  reason: ReportReasonType;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  details?: string;
}
