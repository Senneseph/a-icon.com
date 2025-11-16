import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./upload/upload.component').then((m) => m.UploadComponent),
  },
  {
    path: 'directory',
    loadComponent: () =>
      import('./directory/directory.component').then((m) => m.DirectoryComponent),
    data: { prerender: false }, // Disable prerendering for this route since it makes API calls
  },
  {
    path: '**',
    redirectTo: '',
  },
];
