import { Global, Module } from '@nestjs/common';
import { MemoryStoreService } from './memory-store.service';

@Global()
@Module({
  providers: [MemoryStoreService],
  exports: [MemoryStoreService],
})
export class CoreModule {}
