import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { catchError, of } from 'rxjs';

interface FaviconListItem {
  id: string;
  slug: string;
  targetDomain: string | null;
  sourceUrl: string;
  createdAt: string;
  assetCount: number;
}

@Component({
  selector: 'app-admin',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './admin.component.html',
  styleUrls: ['./admin.component.scss'],
})
export class AdminComponent implements OnInit {
  // Authentication state
  isAuthenticated = signal<boolean>(false);
  password = '';
  authError = signal<string | null>(null);
  token = signal<string | null>(null);

  // Directory state
  favicons = signal<FaviconListItem[]>([]);
  loading = signal<boolean>(false);
  error = signal<string | null>(null);

  // Selection state
  selectedIds = new Set<string>();
  selectAll = false;

  // Delete state
  deleting = signal<boolean>(false);
  deleteError = signal<string | null>(null);

  constructor(private http: HttpClient) {}

  ngOnInit() {
    // Check if already authenticated
    const storedToken = localStorage.getItem('admin_token');
    if (storedToken) {
      this.verifyToken(storedToken);
    }
  }

  async login() {
    this.authError.set(null);

    this.http
      .post<{ token: string }>('/api/admin/login', { password: this.password })
      .pipe(
        catchError((err) => {
          this.authError.set(
            err.error?.message || 'Invalid password. Please try again.',
          );
          return of(null);
        }),
      )
      .subscribe((result) => {
        if (result) {
          this.token.set(result.token);
          localStorage.setItem('admin_token', result.token);
          this.isAuthenticated.set(true);
          this.password = '';
          this.loadDirectory();
        }
      });
  }

  async verifyToken(token: string) {
    const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);

    this.http
      .post('/api/admin/verify', {}, { headers })
      .pipe(
        catchError(() => {
          localStorage.removeItem('admin_token');
          return of(null);
        }),
      )
      .subscribe((result) => {
        if (result) {
          this.token.set(token);
          this.isAuthenticated.set(true);
          this.loadDirectory();
        }
      });
  }

  logout() {
    const token = this.token();
    if (token) {
      const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
      this.http.post('/api/admin/logout', {}, { headers }).subscribe();
    }

    localStorage.removeItem('admin_token');
    this.token.set(null);
    this.isAuthenticated.set(false);
    this.favicons.set([]);
    this.selectedIds.clear();
  }

  loadDirectory() {
    this.loading.set(true);
    this.error.set(null);

    this.http
      .get<FaviconListItem[]>('/api/directory?sortBy=domain&order=asc')
      .pipe(
        catchError((err) => {
          this.error.set(err.error?.message || 'Failed to load favicons');
          this.loading.set(false);
          return of([]);
        }),
      )
      .subscribe((data) => {
        this.favicons.set(data);
        this.loading.set(false);
      });
  }

  toggleSelection(id: string) {
    if (this.selectedIds.has(id)) {
      this.selectedIds.delete(id);
    } else {
      this.selectedIds.add(id);
    }
    this.updateSelectAllState();
  }

  toggleSelectAll() {
    if (this.selectAll) {
      this.selectedIds.clear();
    } else {
      this.favicons().forEach((f) => this.selectedIds.add(f.id));
    }
    this.selectAll = !this.selectAll;
  }

  updateSelectAllState() {
    this.selectAll =
      this.favicons().length > 0 &&
      this.selectedIds.size === this.favicons().length;
  }

  isSelected(id: string): boolean {
    return this.selectedIds.has(id);
  }

  async deleteSelected() {
    if (this.selectedIds.size === 0) {
      return;
    }

    const count = this.selectedIds.size;
    if (
      !confirm(
        `Are you sure you want to permanently delete ${count} favicon${count > 1 ? 's' : ''}? This action cannot be undone.`,
      )
    ) {
      return;
    }

    this.deleting.set(true);
    this.deleteError.set(null);

    const token = this.token();
    if (!token) {
      this.deleteError.set('Not authenticated');
      this.deleting.set(false);
      return;
    }

    const headers = new HttpHeaders().set('Authorization', `Bearer ${token}`);
    const ids = Array.from(this.selectedIds);

    this.http
      .request('DELETE', '/api/admin/favicons', {
        headers,
        body: { ids },
      })
      .pipe(
        catchError((err) => {
          this.deleteError.set(
            err.error?.message || 'Failed to delete favicons',
          );
          this.deleting.set(false);
          return of(null);
        }),
      )
      .subscribe((result: any) => {
        if (result) {
          // Clear selection
          this.selectedIds.clear();
          this.selectAll = false;

          // Reload directory
          this.loadDirectory();
        }
        this.deleting.set(false);
      });
  }
}
