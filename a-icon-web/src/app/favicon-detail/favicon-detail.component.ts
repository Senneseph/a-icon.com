import { Component, OnInit, inject, computed, effect, PLATFORM_ID } from '@angular/core';
import { CommonModule, isPlatformBrowser } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { ActivatedRoute, Router } from '@angular/router';
import { Meta, Title } from '@angular/platform-browser';
import { toSignal } from '@angular/core/rxjs-interop';
import { catchError, map, of, switchMap } from 'rxjs';

interface FaviconAsset {
  id: string;
  type: string;
  size: string; // e.g., "16x16", "32x32", "MULTI"
  format: string;
  mimeType: string;
  url: string;
}

interface FaviconDetail {
  id: string;
  slug: string;
  title: string | null;
  targetDomain: string | null;
  publishedUrl: string;
  sourceUrl: string;
  sourceType: string;
  isPublished: boolean;
  createdAt: string;
  generatedAt: string | null;
  generationStatus: string;
  generationError: string | null;
  metadata: string | null;
  hasSteganography: boolean;
  assets: FaviconAsset[];
}

@Component({
  selector: 'app-favicon-detail',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './favicon-detail.component.html',
  styleUrls: ['./favicon-detail.component.scss'],
})
export class FaviconDetailComponent implements OnInit {
  private http = inject(HttpClient);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private meta = inject(Meta);
  private titleService = inject(Title);
  private platformId = inject(PLATFORM_ID);

  // Fetch favicon data based on slug
  private faviconData = toSignal(
    this.route.params.pipe(
      map((params) => params['slug']),
      switchMap((currentSlug) => {
        if (!currentSlug) return of({ data: null, error: 'No slug provided' });

        const url = `/api/favicons/${currentSlug}`;
        console.log('[FaviconDetailComponent] Fetching:', url);

        return this.http.get<FaviconDetail>(url).pipe(
          map((data) => ({ data, error: null })),
          catchError((err) => {
            console.error('[FaviconDetailComponent] Error:', err);
            return of({ data: null, error: err.error?.message || 'Failed to load favicon' });
          })
        );
      })
    ),
    { initialValue: { data: null, error: null } }
  );

  favicon = computed(() => this.faviconData()?.data);
  error = computed(() => this.faviconData()?.error);
  loading = computed(() => !this.faviconData());

  // Computed full published URL
  fullPublishedUrl = computed(() => {
    const favicon = this.favicon();
    if (!favicon) return '';
    return `https://a-icon.com/favicon/${favicon.slug}`;
  });

  constructor() {
    // Update meta tags when favicon data changes
    effect(() => {
      const favicon = this.favicon();
      if (favicon) {
        this.updateMetaTags(favicon);
      }
    });
  }

  ngOnInit() {
    console.log('[FaviconDetailComponent] Initialized');
  }

  private updateMetaTags(favicon: FaviconDetail) {
    const baseUrl = 'https://a-icon.com';
    const pageUrl = `${baseUrl}/favicon/${favicon.slug}`;
    const imageUrl = `${baseUrl}${favicon.sourceUrl}`;
    const title = favicon.title || `Favicon ${favicon.slug}`;
    const description = `View and download favicon ${favicon.slug}${favicon.title ? ` - ${favicon.title}` : ''}. Generated on ${new Date(favicon.createdAt).toLocaleDateString()}.`;

    // Set page title
    this.titleService.setTitle(`${title} | a-icon.com`);

    // Open Graph meta tags (Facebook, LinkedIn, etc.)
    this.meta.updateTag({ property: 'og:title', content: title });
    this.meta.updateTag({ property: 'og:description', content: description });
    this.meta.updateTag({ property: 'og:image', content: imageUrl });
    this.meta.updateTag({ property: 'og:url', content: pageUrl });
    this.meta.updateTag({ property: 'og:type', content: 'website' });
    this.meta.updateTag({ property: 'og:site_name', content: 'a-icon.com' });

    // Twitter Card meta tags
    this.meta.updateTag({ name: 'twitter:card', content: 'summary_large_image' });
    this.meta.updateTag({ name: 'twitter:title', content: title });
    this.meta.updateTag({ name: 'twitter:description', content: description });
    this.meta.updateTag({ name: 'twitter:image', content: imageUrl });

    // Additional meta tags
    this.meta.updateTag({ name: 'description', content: description });
  }

  goToDirectory() {
    this.router.navigate(['/directory']);
  }

  copyToClipboard(text: string, event: Event) {
    event.preventDefault();
    navigator.clipboard.writeText(text).then(() => {
      const button = event.target as HTMLButtonElement;
      const originalText = button.textContent;
      button.textContent = '✓ Copied!';
      setTimeout(() => {
        button.textContent = originalText;
      }, 2000);
    });
  }

  downloadAsset(url: string, filename: string): void {
    // Only run in browser, not during SSR
    if (!isPlatformBrowser(this.platformId)) {
      return;
    }

    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  getAssetFilename(asset: FaviconAsset): string {
    const favicon = this.favicon();
    if (!favicon) return 'asset';

    const domain = favicon.targetDomain || 'a-icon.com';
    const size = asset.size === 'MULTI' ? 'favicon' : asset.size;
    const extension = asset.format.startsWith('.') ? asset.format.substring(1) : asset.format;

    return `${size}-${domain}.${extension}`;
  }

  formatDate(dateString: string): string {
    return new Date(dateString).toLocaleString();
  }

  getAssetsByType(type: string): FaviconAsset[] {
    return this.favicon()?.assets.filter((a) => a.type === type) || [];
  }

  previewInBrowser(): void {
    // Only run in browser, not during SSR
    if (!isPlatformBrowser(this.platformId)) {
      return;
    }

    const favicon = this.favicon();
    if (!favicon) return;

    // Use source image directly (same as directory page)
    this.changeFavicon(favicon.sourceUrl);
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

    console.log('[FaviconDetailComponent] Changed favicon to:', iconUrl);
  }
}

