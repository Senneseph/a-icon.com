import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { ActivatedRoute, Router } from '@angular/router';
import { environment } from '../../environments/environment';
import { toSignal } from '@angular/core/rxjs-interop';
import { catchError, map, of, switchMap } from 'rxjs';

interface FaviconAsset {
  id: string;
  type: string;
  size: number;
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

  // Get slug from route params
  private slug = toSignal(this.route.params.pipe(map((params) => params['slug'])));

  // Fetch favicon data based on slug
  private faviconData = toSignal(
    computed(() => {
      const currentSlug = this.slug();
      if (!currentSlug) return of({ data: null, error: 'No slug provided' });

      const url = `${environment.apiUrl}/favicons/${currentSlug}`;
      console.log('[FaviconDetailComponent] Fetching:', url);

      return this.http.get<FaviconDetail>(url).pipe(
        map((data) => ({ data, error: null })),
        catchError((err) => {
          console.error('[FaviconDetailComponent] Error:', err);
          return of({ data: null, error: err.error?.message || 'Failed to load favicon' });
        })
      );
    })(),
    { initialValue: { data: null, error: null } }
  );

  favicon = computed(() => this.faviconData()?.data);
  error = computed(() => this.faviconData()?.error);
  loading = computed(() => !this.faviconData());

  ngOnInit() {
    console.log('[FaviconDetailComponent] Initialized');
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

  downloadAsset(url: string, filename: string) {
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
  }

  formatDate(dateString: string): string {
    return new Date(dateString).toLocaleString();
  }

  getAssetsByType(type: string): FaviconAsset[] {
    return this.favicon()?.assets.filter((a) => a.type === type) || [];
  }
}

