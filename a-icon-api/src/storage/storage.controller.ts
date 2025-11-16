import { Controller, Get, Param, Res, NotFoundException } from '@nestjs/common';
import type { Response } from 'express';
import { StorageService } from './storage.service';

@Controller('storage')
export class StorageController {
  constructor(private readonly storage: StorageService) {}

  /**
   * GET /api/storage/sources/:faviconId/original
   * Serve the original source image for a favicon
   */
  @Get('sources/:faviconId/original')
  async getSourceImage(@Param('faviconId') faviconId: string, @Res() res: Response) {
    try {
      const key = `sources/${faviconId}/original`;
      const buffer = await this.storage.getObject(key);

      // Infer content type from the first few bytes or default to PNG
      const contentType = this.detectImageMimeType(buffer);

      res.setHeader('Content-Type', contentType);
      res.setHeader('Cache-Control', 'public, max-age=31536000'); // Cache for 1 year
      res.send(buffer);
    } catch (err) {
      throw new NotFoundException('Source image not found');
    }
  }

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
      res.setHeader('Cache-Control', 'public, max-age=31536000'); // Cache for 1 year
      res.send(buffer);
    } catch (err) {
      throw new NotFoundException('File not found');
    }
  }

  /**
   * Detect image MIME type from buffer
   */
  private detectImageMimeType(buffer: Buffer): string {
    // Check magic bytes
    if (buffer.length < 4) return 'application/octet-stream';

    // PNG: 89 50 4E 47
    if (buffer[0] === 0x89 && buffer[1] === 0x50 && buffer[2] === 0x4e && buffer[3] === 0x47) {
      return 'image/png';
    }

    // JPEG: FF D8 FF
    if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
      return 'image/jpeg';
    }

    // GIF: 47 49 46
    if (buffer[0] === 0x47 && buffer[1] === 0x49 && buffer[2] === 0x46) {
      return 'image/gif';
    }

    // SVG: starts with < or whitespace then <
    const str = buffer.toString('utf8', 0, Math.min(100, buffer.length));
    if (str.trim().startsWith('<svg') || str.trim().startsWith('<?xml')) {
      return 'image/svg+xml';
    }

    // Default to PNG for unknown image types
    return 'image/png';
  }
}

