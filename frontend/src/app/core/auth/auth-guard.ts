import { Injectable } from "@angular/core";
import { CanActivateFn } from "@angular/router";
import { Router } from "@angular/router";
import { inject } from "@angular/core";
import { Auth } from "./auth";

@Injectable({
  providedIn: 'root',
})
export class AuthGuardService {
  constructor(private auth: Auth, private router: Router) { }
  canActivate(): boolean {
    if (this.auth.isAuthenticated()) {
      return true;
    } else {
      this.router.navigate(['/login']);
      return false;
    }
  }

}

export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthGuardService);
  return authService.canActivate();
}
