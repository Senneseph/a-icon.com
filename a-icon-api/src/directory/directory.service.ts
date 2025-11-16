import { Injectable } from '@nestjs/common';
import { DatabaseService, Favicon } from '../database/database.service';

export interface DirectoryQuery {
  page: number;
  pageSize: number;
  sortBy: 'date' | 'url' | 'domain';
  sortDir: 'asc' | 'desc';
}

@Injectable()
export class DirectoryService {
  constructor(private readonly db: DatabaseService) {}

  listPublishedFavicons(query: DirectoryQuery) {
    const { page, pageSize, sortBy, sortDir } = query;
    const offset = (page - 1) * pageSize;

    // Map sortBy to column name
    const columnMap: Record<string, string> = {
      date: 'created_at',
      url: 'published_url',
      domain: 'target_domain',
    };
    const orderColumn = columnMap[sortBy] || 'created_at';
    const orderDirection = sortDir === 'asc' ? 'ASC' : 'DESC';

    const countStmt = this.db.getDb().prepare('SELECT COUNT(*) as total FROM favicons WHERE is_published = 1');
    const total = (countStmt.get() as { total: number }).total;

    const stmt = this.db
      .getDb()
      .prepare(
        `SELECT * FROM favicons WHERE is_published = 1 ORDER BY ${orderColumn} ${orderDirection} LIMIT ? OFFSET ?`,
      );
    const items = stmt.all(pageSize, offset) as Favicon[];

    // Get asset counts for each favicon
    const assetCountStmt = this.db.getDb().prepare('SELECT COUNT(*) as count FROM favicon_assets WHERE favicon_id = ?');

    return items.map((f) => {
      const assetCount = (assetCountStmt.get(f.id) as { count: number }).count;
      return {
        id: f.id,
        slug: f.slug,
        sourceUrl: `/api/storage/sources/${f.id}/original`,
        createdAt: f.created_at,
        assetCount,
      };
    });
  }
}

