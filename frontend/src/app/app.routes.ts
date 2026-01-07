import { Routes } from '@angular/router';
import { authGuard } from './core/auth/auth-guard';

export const routes: Routes = [
    {
        path: 'auth/callback',
        loadComponent: () =>
            import('./features/auth-callback/auth-callback')
                .then(m => m.AuthCallback)
    },
    {
        path: 'login',
        loadComponent: () =>
            import('./features/login/login').then(m => m.Login)
    },
    {
        path: 'uploadf',
        canActivate: [authGuard],
        loadComponent: () =>
            import('./features/upload/upload').then(m => m.Upload)
    },
    {
        path: '',
        redirectTo: 'login',
        pathMatch: 'full'

    }

]
