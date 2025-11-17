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
    @Body('metadata') metadata?: string,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }

    // Validate file size (max 0.5 MB)
    const maxSize = 1 * 512 * 1024; // 0.5 MB
    if (file.size > maxSize) {
      const sizeMB = (file.size / (1024 * 1024)).toFixed(2);
      throw new BadRequestException(
        `File size (${sizeMB}MB) exceeds the maximum allowed size of 0.5 MB`,
      );
    }

    // Validate file type
    if (!file.mimetype.startsWith('image/')) {
      throw new BadRequestException('Only image files are allowed');
    }

    // Validate domain name if provided
    if (targetDomain) {
      this.validateDomain(targetDomain);
    }

    // Validate metadata length if provided
    if (metadata && metadata.length > 256) {
      throw new BadRequestException(
        'Metadata must not exceed 256 characters',
      );
    }

    const result = await this.faviconService.createFavicon({
      sourceBuffer: file.buffer,
      sourceMimeType: file.mimetype,
      sourceType: 'UPLOAD',
      title,
      targetDomain,
      metadata,
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
    @Body('metadata') metadata?: string,
  ) {
    if (!dataUrl) {
      throw new BadRequestException('No canvas data provided');
    }

    // Extract base64 and convert to buffer
    const base64Data = dataUrl.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');

    // Validate file size (max 0.5 MB)
    const maxSize = 1 * 512 * 1024; // 0.5 MB
    if (buffer.length > maxSize) {
      const sizeMB = (buffer.length / (1024 * 1024)).toFixed(2);
      throw new BadRequestException(
        `Image size (${sizeMB}MB) exceeds the maximum allowed size of 0.5 MB`,
      );
    }

    // Validate domain name if provided
    if (targetDomain) {
      this.validateDomain(targetDomain);
    }

    // Validate metadata length if provided
    if (metadata && metadata.length > 256) {
      throw new BadRequestException(
        'Metadata must not exceed 256 characters',
      );
    }

    const result = await this.faviconService.createFavicon({
      sourceBuffer: buffer,
      sourceMimeType: 'image/png',
      sourceType: 'CANVAS',
      title,
      targetDomain,
      metadata,
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
      metadata: favicon.metadata,
      hasSteganography: favicon.has_steganography === 1,
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

  /**
   * Validate domain name format
   * - Max 256 characters
   * - Must contain a "." with content before and after it (TLD syntax)
   */
  private validateDomain(domain: string): void {
    // Check length
    if (domain.length > 256) {
      throw new BadRequestException(
        'Domain name must not exceed 256 characters',
      );
    }

    // Check for dot presence
    if (!domain.includes('.')) {
      throw new BadRequestException(
        'Domain name must contain at least one dot (.)',
      );
    }

    // Check that there's content before and after the dot
    const parts = domain.split('.');
    if (parts.length < 2) {
      throw new BadRequestException(
        'Domain name must have content before and after the dot',
      );
    }

    // Check that no part is empty
    if (parts.some((part) => part.length === 0)) {
      throw new BadRequestException(
        'Domain name cannot have empty parts (e.g., "example..com")',
      );
    }

    // Validate domain format with regex
    const domainRegex =
      /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;
    if (!domainRegex.test(domain)) {
      throw new BadRequestException(
        'Invalid domain name format. Domain must contain only letters, numbers, hyphens, and dots, and follow TLD syntax',
      );
    }
  }
}
