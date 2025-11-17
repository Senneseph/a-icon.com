import { Injectable, OnModuleInit } from '@nestjs/common';
import {
  writeFileSync,
  readFileSync,
  existsSync,
  mkdirSync,
  unlinkSync,
} from 'fs';
import { join } from 'path';

export interface StoredObject {
  key: string;
  url?: string;
}

@Injectable()
export class StorageService implements OnModuleInit {
  private storageRoot: string;

  onModuleInit() {
    this.storageRoot = process.env.STORAGE_ROOT || join(process.cwd(), 'data', 'storage');
    if (!existsSync(this.storageRoot)) {
      mkdirSync(this.storageRoot, { recursive: true });
    }
  }

  async putObject(key: string, data: Buffer, _contentType: string): Promise<StoredObject> {
    const filePath = join(this.storageRoot, key);
    const dir = join(this.storageRoot, key.split('/').slice(0, -1).join('/'));
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    writeFileSync(filePath, data);
    return { key, url: this.getPublicUrl(key) };
  }

  async getObject(key: string): Promise<Buffer> {
    const filePath = join(this.storageRoot, key);
    if (!existsSync(filePath)) {
      throw new Error(`Object not found: ${key}`);
    }
    return readFileSync(filePath);
  }

  async deleteObject(key: string): Promise<void> {
    const filePath = join(this.storageRoot, key);
    if (existsSync(filePath)) {
      unlinkSync(filePath);
    }
  }

  getPublicUrl(key: string): string {
    // In production, this would be a CDN or DO Spaces URL.
    // For local dev, we'll serve from /api/storage/:key
    return `/api/storage/${key}`;
  }
}

