import { Component, inject, signal, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router, RouterLink } from '@angular/router';
import { catchError, of } from 'rxjs';

interface FaviconListItem {
  id: string;
  slug: string;
  targetDomain: string | null;
  sourceUrl: string;
  createdAt: string;
  assetCount: number;
}

type SortField = 'createdAt' | 'slug' | 'domain';
type SortOrder = 'asc' | 'desc';

@Component({
  selector: 'app-directory',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './directory.component.html',
  styleUrls: ['./directory.component.scss'],
})
export class DirectoryComponent {
  private http = inject(HttpClient);
  private router = inject(Router);

  // Signals for reactive state
  sortField = signal<SortField>('domain');
  sortOrder = signal<SortOrder>('asc');

  // Signals for data state
  favicons = signal<FaviconListItem[]>([]);
  loading = signal<boolean>(true);
  error = signal<string | null>(null);

  constructor() {
    // Use effect to reactively fetch data when sort parameters change
    effect(() => {
      const url = `/api/directory?sortBy=${this.sortField()}&order=${this.sortOrder()}`;
      console.log('[DirectoryComponent] Fetching data from:', url);

      this.loading.set(true);
      this.error.set(null);

      this.http.get<FaviconListItem[]>(url).pipe(
        catchError(err => {
          console.error('[DirectoryComponent] HTTP error:', err);
          this.error.set(err.error?.message || 'Failed to load favicons');
          this.loading.set(false);
          return of([]);
        })
      ).subscribe(data => {
        this.favicons.set(data);
        this.loading.set(false);
      });
    });
  }

  setSortField(field: SortField): void {
    if (this.sortField() === field) {
      this.sortOrder.set(this.sortOrder() === 'asc' ? 'desc' : 'asc');
    } else {
      this.sortField.set(field);
      // Default to ascending for domain and slug, descending for date
      this.sortOrder.set(field === 'createdAt' ? 'desc' : 'asc');
    }
  }

  goToUpload(): void {
    this.router.navigate(['/']);
  }

  copyToClipboard(text: string, event: Event): void {
    event.stopPropagation();
    navigator.clipboard.writeText(text).then(() => {
      alert('URL copied to clipboard!');
    });
  }

  formatDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  previewInBrowser(sourceUrl: string, event: Event): void {
    event.stopPropagation();

    // Only run in browser, not during SSR
    if (typeof document === 'undefined') {
      return;
    }

    this.changeFavicon(sourceUrl);
  }

  private changeFavicon(iconUrl: string): void {
    // Remove existing favicon links
    const existingLinks = document.querySelectorAll("link[rel*='icon']");
    existingLinks.forEach(link => link.remove());

    // Add new favicon link
    const link = document.createElement('link');
    link.rel = 'icon';
    link.type = 'image/x-icon';
    link.href = iconUrl;
    document.head.appendChild(link);

    // Also add apple-touch-icon for better support
    const appleLink = document.createElement('link');
    appleLink.rel = 'apple-touch-icon';
    appleLink.href = iconUrl;
    document.head.appendChild(appleLink);

    console.log('[DirectoryComponent] Changed favicon to:', iconUrl);
  }
}

