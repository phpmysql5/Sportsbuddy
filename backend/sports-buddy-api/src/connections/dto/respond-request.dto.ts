import { IsIn, IsString } from 'class-validator';

const ACTIONS = ['accept', 'reject'] as const;
export type RequestAction = (typeof ACTIONS)[number];

export class RespondRequestDto {
  @IsString()
  @IsIn(ACTIONS)
  action: RequestAction;
}
