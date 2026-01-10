import { Login } from "./features/login/login";
import { AuthCallback } from "./features/auth-callback/auth-callback";
import { Upload } from "./features/upload/upload";
import { authGuard } from "./core/auth/auth-guard";
import { Routes } from "@angular/router";

export const routes: Routes = [
    {
        path: 'login',
        component: Login,
    },
    {
        path: 'auth-callback',
        component: AuthCallback,
    },
    {
        path: 'upload',
        component: Upload,
        canActivate: [authGuard],
    },
    {
        path: '',
        redirectTo: '/upload',
        pathMatch: 'full',
    },
    {
        path: '**',
        redirectTo: '/upload',
    },

];