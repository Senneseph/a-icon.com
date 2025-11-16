import { Component, OnInit, inject, PLATFORM_ID, signal, computed } from '@angular/core';
import { CommonModule, isPlatformBrowser } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router, RouterLink } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { catchError, map, of } from 'rxjs';

interface FaviconListItem {
  id: string;
  slug: string;
  sourceUrl: string;
  createdAt: string;
  assetCount: number;
}

type SortField = 'createdAt' | 'slug';
type SortOrder = 'asc' | 'desc';

@Component({
  selector: 'app-directory',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './directory.component.html',
  styleUrls: ['./directory.component.scss'],
})
export class DirectoryComponent implements OnInit {
  private http = inject(HttpClient);
  private router = inject(Router);
  private platformId = inject(PLATFORM_ID);

  // Signals for reactive state
  sortField = signal<SortField>('createdAt');
  sortOrder = signal<SortOrder>('desc');

  // Computed URL based on sort parameters
  private apiUrl = computed(() => {
    const url = `/api/directory?sortBy=${this.sortField()}&order=${this.sortOrder()}`;
    console.log('[DirectoryComponent] Computed URL:', url);
    return url;
  });

  // Use toSignal to convert HTTP observable to signal - this properly handles SSR and hydration
  private faviconData = toSignal(
    computed(() => {
      const url = this.apiUrl();
      console.log('[DirectoryComponent] Fetching data from:', url);
      return this.http.get<FaviconListItem[]>(url).pipe(
        map(data => ({ data, error: null })),
        catchError(err => {
          console.error('[DirectoryComponent] HTTP error:', err);
          return of({ data: null, error: err.error?.message || 'Failed to load favicons' });
        })
      );
    })(),
    { initialValue: { data: null, error: null } }
  );

  // Computed properties for template
  favicons = computed(() => this.faviconData().data || []);
  loading = computed(() => this.faviconData().data === null && this.faviconData().error === null);
  error = computed(() => this.faviconData().error);

  ngOnInit(): void {
    const isBrowser = isPlatformBrowser(this.platformId);
    console.log(`[DirectoryComponent] ngOnInit called - Platform: ${isBrowser ? 'BROWSER' : 'SERVER'}`);
  }

  setSortField(field: SortField): void {
    if (this.sortField() === field) {
      this.sortOrder.set(this.sortOrder() === 'asc' ? 'desc' : 'asc');
    } else {
      this.sortField.set(field);
      this.sortOrder.set('desc');
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
  }
}

