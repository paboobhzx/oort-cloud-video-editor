import { CanActivateFn } from '@angular/router';
import { inject } from '@angular/core';
import { Auth } from './auth';
import { Router } from '@angular/router';

export const authGuard: CanActivateFn = () => {
  const auth = inject(Auth);
  const router = inject(Router);

  if (auth.isAuthenticated()) {
    return true;
  }
  router.navigate(['/login'])
  return true;
};
