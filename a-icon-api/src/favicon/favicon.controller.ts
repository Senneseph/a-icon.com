import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  UploadedFile,
  UseInterceptors,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { FaviconService } from './favicon.service';

@Controller('favicons')
export class FaviconController {
  constructor(private readonly faviconService: FaviconService) {}

  /**
   * POST /api/favicons/upload
   * Upload an image and generate a favicon with a unique URL.
   */
  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  async uploadFavicon(
    @UploadedFile() file: Express.Multer.File | undefined,
    @Body('title') title?: string,
    @Body('targetDomain') targetDomain?: string,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    const result = await this.faviconService.createFavicon({
      sourceBuffer: file.buffer,
      sourceMimeType: file.mimetype,
      sourceType: 'UPLOAD',
      title,
      targetDomain,
    });

    // Return the full favicon details including assets
    return this.getFavicon(result.slug);
  }

  /**
   * POST /api/favicons/canvas
   * Submit a canvas-created icon (base64 data URL).
   */
  @Post('canvas')
  async createFromCanvas(
    @Body('dataUrl') dataUrl: string,
    @Body('title') title?: string,
    @Body('targetDomain') targetDomain?: string,
  ) {
    if (!dataUrl) {
      throw new BadRequestException('No canvas data provided');
    }

    // Extract base64 and convert to buffer
    const base64Data = dataUrl.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');

    const result = await this.faviconService.createFavicon({
      sourceBuffer: buffer,
      sourceMimeType: 'image/png',
      sourceType: 'CANVAS',
      title,
      targetDomain,
    });

    // Return the full favicon details including assets
    return this.getFavicon(result.slug);
  }

  /**
   * GET /api/favicons/:slug
   * Retrieve favicon metadata and list of assets.
   */
  @Get(':slug')
  getFavicon(@Param('slug') slug: string) {
    const favicon = this.faviconService.getFaviconBySlug(slug);
    if (!favicon) {
      throw new NotFoundException('Favicon not found');
    }

    const assets = this.faviconService.getAssetsByFaviconId(favicon.id);

    // Get the source image URL
    const sourceUrl = `/api/storage/sources/${favicon.id}/original`;

    return {
      id: favicon.id,
      slug: favicon.slug,
      title: favicon.title,
      targetDomain: favicon.target_domain,
      publishedUrl: favicon.published_url,
      sourceUrl, // Add sourceUrl for frontend
      sourceType: favicon.source_type,
      isPublished: favicon.is_published === 1,
      createdAt: favicon.created_at,
      generatedAt: favicon.generated_at,
      generationStatus: favicon.generation_status,
      generationError: favicon.generation_error,
      assets: assets.map((a) => ({
        id: a.id,
        type: a.type,
        size: a.size,
        format: a.format,
        mimeType: a.mime_type,
        url: `/api/storage/${a.storage_key}`,
      })),
    };
  }
}
