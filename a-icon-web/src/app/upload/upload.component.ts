import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';

interface FaviconResponse {
  id: string;
  slug: string;
  sourceUrl: string;
  createdAt: string;
  assets: Array<{
    id: string;
    type: string;
    size: string;
    format: string;
    url: string;
  }>;
}

@Component({
  selector: 'app-upload',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './upload.component.html',
  styleUrls: ['./upload.component.scss'],
})
export class UploadComponent {
  private http = inject(HttpClient);
  private router = inject(Router);

  selectedFile: File | null = null;
  previewUrl: string | null = null;
  uploading = false;
  error: string | null = null;
  result: FaviconResponse | null = null;

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files[0]) {
      const file = input.files[0];

      // Validate file type
      if (!file.type.startsWith('image/')) {
        this.error = 'Please select an image file';
        return;
      }

      // Validate file size (max 10MB)
      if (file.size > 10 * 1024 * 1024) {
        this.error = 'File size must be less than 10MB';
        return;
      }

      this.selectedFile = file;
      this.error = null;

      // Create preview
      const reader = new FileReader();
      reader.onload = (e) => {
        this.previewUrl = e.target?.result as string;
      };
      reader.readAsDataURL(file);
    }
  }

  uploadImage(): void {
    if (!this.selectedFile) {
      this.error = 'Please select a file first';
      return;
    }

    this.uploading = true;
    this.error = null;

    const formData = new FormData();
    formData.append('file', this.selectedFile);

    this.http
      .post<FaviconResponse>(`/api/favicons/upload`, formData)
      .subscribe({
        next: (response) => {
          this.uploading = false;
          // Navigate to the favicon detail page upon successful upload
          this.router.navigate(['/favicon', response.slug]);
        },
        error: (err) => {
          this.uploading = false;
          this.error = err.error?.message || 'Failed to upload image';
          console.error('Upload error:', err);
        },
      });
  }

  reset(): void {
    this.selectedFile = null;
    this.previewUrl = null;
    this.error = null;
    this.result = null;
  }

  viewDirectory(): void {
    this.router.navigate(['/directory']);
  }

  copyToClipboard(text: string): void {
    navigator.clipboard.writeText(text).then(() => {
      alert('Copied to clipboard!');
    });
  }
}

