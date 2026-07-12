import { IsUUID } from 'class-validator';

export class SendRequestDto {
  @IsUUID()
  receiverId: string;
}
