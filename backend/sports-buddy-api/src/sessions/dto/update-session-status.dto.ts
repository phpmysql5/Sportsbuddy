import { IsIn, IsString } from 'class-validator';
import { SessionPlanStatus } from '@prisma/client';

const SESSION_STATUSES: SessionPlanStatus[] = [
  'open',
  'confirmed',
  'completed',
  'cancelled',
];

export class UpdateSessionStatusDto {
  @IsString()
  @IsIn(SESSION_STATUSES)
  status: SessionPlanStatus;
}
