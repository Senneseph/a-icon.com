import { Injectable } from '@nestjs/common';
import sharp from 'sharp';

export interface GeneratedAsset {
  type: string; // 'ICO', 'PNG', 'SVG'
  size: string | null; // '16x16', '192x192', 'MULTI', etc.
  format: string; // '.ico', '.png', '.svg'
  mimeType: string;
  buffer: Buffer;
}

@Injectable()
export class FaviconGeneratorService {
  /**
   * Generate all standard favicon assets from a source image buffer.
   * Supports PNG, JPEG, WebP, SVG input.
   */
  async generateFromImage(sourceBuffer: Buffer): Promise<GeneratedAsset[]> {
    const assets: GeneratedAsset[] = [];

    // Standard favicon sizes (PNG)
    const pngSizes = [16, 32, 48, 64, 96, 128, 192, 256, 512];
    for (const size of pngSizes) {
      const buffer = await sharp(sourceBuffer)
        .resize(size, size, { fit: 'cover', position: 'center' })
        .png()
        .toBuffer();

      assets.push({
        type: 'PNG',
        size: `${size}x${size}`,
        format: '.png',
        mimeType: 'image/png',
        buffer,
      });
    }

    // Apple touch icons
    const appleSizes = [120, 152, 167, 180];
    for (const size of appleSizes) {
      const buffer = await sharp(sourceBuffer)
        .resize(size, size, { fit: 'cover', position: 'center' })
        .png()
        .toBuffer();

      assets.push({
        type: 'PNG',
        size: `${size}x${size}`,
        format: '.png',
        mimeType: 'image/png',
        buffer,
      });
    }

    // Multi-resolution ICO (16, 32, 48)
    // Sharp doesn't natively support ICO, so we'll generate a 32x32 PNG as a fallback for now.
    // In production, you'd use a library like `to-ico` or `png-to-ico`.
    const ico32 = await sharp(sourceBuffer)
      .resize(32, 32, { fit: 'cover', position: 'center' })
      .png()
      .toBuffer();

    assets.push({
      type: 'ICO',
      size: 'MULTI',
      format: '.ico',
      mimeType: 'image/x-icon',
      buffer: ico32, // Placeholder; real ICO would combine multiple sizes
    });

    return assets;
  }

  /**
   * Generate assets from a canvas-created image (base64 data URL or buffer).
   */
  async generateFromCanvas(canvasDataUrl: string): Promise<GeneratedAsset[]> {
    // Extract base64 data from data URL (e.g., "data:image/png;base64,...")
    const base64Data = canvasDataUrl.replace(/^data:image\/\w+;base64,/, '');
    const buffer = Buffer.from(base64Data, 'base64');
    return this.generateFromImage(buffer);
  }
}

