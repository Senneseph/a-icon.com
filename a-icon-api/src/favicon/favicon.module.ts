import { Module } from '@nestjs/common';
import { FaviconService } from './favicon.service';
import { FaviconController } from './favicon.controller';
import { FaviconGeneratorService } from './favicon-generator.service';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [StorageModule],
  controllers: [FaviconController],
  providers: [FaviconService, FaviconGeneratorService],
  exports: [FaviconService],
})
export class FaviconModule {}

