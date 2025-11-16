import { Injectable } from '@nestjs/common';
import { nanoid } from 'nanoid';
import { DatabaseService, Favicon, FaviconAsset } from '../database/database.service';
import { StorageService } from '../storage/storage.service';
import { FaviconGeneratorService } from './favicon-generator.service';

export interface CreateFaviconDto {
  sourceBuffer: Buffer;
  sourceMimeType: string;
  sourceType: 'UPLOAD' | 'CANVAS';
  title?: string;
  targetDomain?: string;
}

@Injectable()
export class FaviconService {
  constructor(
    private readonly db: DatabaseService,
    private readonly storage: StorageService,
    private readonly generator: FaviconGeneratorService,
  ) {}

  /**
   * Create a new favicon from an uploaded image or canvas data.
   * Returns the favicon ID and slug.
   */
  async createFavicon(dto: CreateFaviconDto): Promise<{ id: string; slug: string }> {
    const id = nanoid();
    const slug = nanoid(10); // Short, URL-safe unique identifier
    const now = new Date().toISOString();

    // Store the original source image
    const sourceKey = `sources/${id}/original`;
    await this.storage.putObject(sourceKey, dto.sourceBuffer, dto.sourceMimeType);

    // Create the favicon record
    const favicon: Favicon = {
      id,
      slug,
      title: dto.title || null,
      target_domain: dto.targetDomain || null,
      published_url: `/f/${slug}`,
      canonical_svg_key: null,
      source_type: dto.sourceType,
      source_original_mime: dto.sourceMimeType,
      is_published: 1,
      created_at: now,
      updated_at: now,
      generated_at: null,
      generation_status: 'PENDING',
      generation_error: null,
    };

    this.db.insertFavicon(favicon);

    // Generate all favicon assets asynchronously (in real production, use a queue)
    this.generateAssets(id, slug, dto.sourceBuffer).catch((err) => {
      console.error(`Failed to generate assets for favicon ${id}:`, err);
      this.db.updateFaviconStatus(id, 'FAILED', err.message, null);
    });

    return { id, slug };
  }

  private async generateAssets(faviconId: string, slug: string, sourceBuffer: Buffer): Promise<void> {
    try {
      const generatedAssets = await this.generator.generateFromImage(sourceBuffer);

      for (const asset of generatedAssets) {
        const assetId = nanoid();
        const storageKey = `favicons/${slug}/${asset.size || 'multi'}${asset.format}`;

        await this.storage.putObject(storageKey, asset.buffer, asset.mimeType);

        const faviconAsset: FaviconAsset = {
          id: assetId,
          favicon_id: faviconId,
          type: asset.type,
          size: asset.size,
          format: asset.format,
          storage_key: storageKey,
          mime_type: asset.mimeType,
          created_at: new Date().toISOString(),
        };

        this.db.insertFaviconAsset(faviconAsset);
      }

      this.db.updateFaviconStatus(faviconId, 'SUCCESS', null, new Date().toISOString());
    } catch (err) {
      throw err;
    }
  }

  /**
   * Retrieve a favicon by its slug.
   */
  getFaviconBySlug(slug: string): Favicon | undefined {
    return this.db.getFaviconBySlug(slug);
  }

  /**
   * Get all assets for a favicon.
   */
  getAssetsByFaviconId(faviconId: string): FaviconAsset[] {
    return this.db.getAssetsByFaviconId(faviconId);
  }
}

