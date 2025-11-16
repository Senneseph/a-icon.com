import { Controller, Get, Query } from '@nestjs/common';
import { DirectoryService } from './directory.service';

@Controller('directory')
export class DirectoryController {
  constructor(private readonly directoryService: DirectoryService) {}

  @Get()
  listDirectory(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('sortBy') sortBy?: string,
    @Query('order') order?: string, // Frontend sends 'order' not 'sortDir'
  ) {
    // Map frontend sortBy values to backend column names
    const sortByMap: Record<string, 'date' | 'url' | 'domain'> = {
      createdAt: 'date',
      slug: 'url',
    };

    const query = {
      page: Number(page) || 1,
      pageSize: Number(pageSize) || 100, // Increase default to show more items
      sortBy: sortByMap[sortBy || 'createdAt'] || 'date',
      sortDir: (order as 'asc' | 'desc') || 'desc',
    };

    return this.directoryService.listPublishedFavicons(query);
  }
}

