import { Injectable } from '@angular/core';

@Injectable({
  providedIn: 'root',
})
export class Auth {
  private readonly TOKEN_KEY = 'access_token';

  setToken(token: string) {
    localStorage.setItem(this.TOKEN_KEY, token);
  }
  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY);
  }
  isAuthenticated(): boolean {
    return !!this.getToken();
  }
  logout() {
    localStorage.removeItem(this.TOKEN_KEY);
  }
}
