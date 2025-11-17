import {
  Controller,
  Post,
  Delete,
  Body,
  Headers,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { AdminService } from './admin.service';
import { DatabaseService } from '../database/database.service';
import { StorageService } from '../storage/storage.service';

@Controller('admin')
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly db: DatabaseService,
    private readonly storage: StorageService,
  ) {}

  /**
   * POST /api/admin/login
   * Verify admin password and return session token
   */
  @Post('login')
  login(@Body('password') password: string) {
    if (!password) {
      throw new BadRequestException('Password is required');
    }

    const result = this.adminService.verifyPassword(password);

    if (!result) {
      throw new UnauthorizedException('Invalid password');
    }

    return result;
  }

  /**
   * POST /api/admin/logout
   * Invalidate session token
   */
  @Post('logout')
  logout(@Headers('authorization') authHeader: string) {
    const token = this.extractToken(authHeader);
    this.adminService.logout(token);
    return { success: true };
  }

  /**
   * POST /api/admin/verify
   * Verify if token is still valid
   */
  @Post('verify')
  verify(@Headers('authorization') authHeader: string) {
    const token = this.extractToken(authHeader);
    const isValid = this.adminService.verifyToken(token);

    if (!isValid) {
      throw new UnauthorizedException('Invalid or expired token');
    }

    return { valid: true };
  }

  /**
   * DELETE /api/admin/favicons
   * Permanently delete multiple favicons
   */
  @Delete('favicons')
  async deleteFavicons(
    @Headers('authorization') authHeader: string,
    @Body('ids') ids: string[],
  ) {
    // Verify admin token
    const token = this.extractToken(authHeader);
    if (!this.adminService.verifyToken(token)) {
      throw new UnauthorizedException('Invalid or expired token');
    }

    if (!ids || !Array.isArray(ids) || ids.length === 0) {
      throw new BadRequestException('ids array is required');
    }

    const results: Array<{
      id: string;
      success: boolean;
      error?: string;
    }> = [];

    for (const id of ids) {
      try {
        // Get favicon to find storage keys
        const favicon = this.db.getFaviconById(id);
        if (!favicon) {
          results.push({ id, success: false, error: 'Not found' });
          continue;
        }

        // Get all assets for this favicon
        const assets = this.db.getAssetsByFaviconId(id);

        // Delete all asset files from storage
        for (const asset of assets) {
          try {
            await this.storage.deleteObject(asset.storage_key);
          } catch (err) {
            console.error(
              `Failed to delete asset ${asset.id} from storage:`,
              err,
            );
          }
        }

        // Delete source image from storage
        const sourceKey = `sources/${id}/original`;
        try {
          await this.storage.deleteObject(sourceKey);
        } catch (err) {
          console.error(`Failed to delete source image for ${id}:`, err);
        }

        // Delete all assets from database
        this.db.deleteAssetsByFaviconId(id);

        // Delete favicon from database
        this.db.deleteFavicon(id);

        results.push({ id, success: true });
      } catch (err) {
        console.error(`Failed to delete favicon ${id}:`, err);
        results.push({
          id,
          success: false,
          error: err instanceof Error ? err.message : 'Unknown error',
        });
      }
    }

    return { results };
  }

  /**
   * Extract Bearer token from Authorization header
   */
  private extractToken(authHeader: string): string {
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid authorization header');
    }

    return authHeader.substring(7);
  }
}

