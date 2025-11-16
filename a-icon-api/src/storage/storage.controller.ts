import { Controller, Get, Param, Res, NotFoundException } from '@nestjs/common';
import type { Response } from 'express';
import { StorageService } from './storage.service';

@Controller('storage')
export class StorageController {
  constructor(private readonly storage: StorageService) {}

  /**
   * GET /api/storage/:key
   * Serve a stored file (for local dev; in production, use CDN/DO Spaces).
   */
  @Get('*')
  async getFile(@Param('0') key: string, @Res() res: Response) {
    try {
      const buffer = await this.storage.getObject(key);
      // Infer content type from extension
      const ext = key.split('.').pop()?.toLowerCase();
      const mimeTypes: Record<string, string> = {
        png: 'image/png',
        ico: 'image/x-icon',
        svg: 'image/svg+xml',
        jpg: 'image/jpeg',
        jpeg: 'image/jpeg',
      };
      const contentType = mimeTypes[ext || ''] || 'application/octet-stream';
      res.setHeader('Content-Type', contentType);
      res.send(buffer);
    } catch (err) {
      throw new NotFoundException('File not found');
    }
  }
}

