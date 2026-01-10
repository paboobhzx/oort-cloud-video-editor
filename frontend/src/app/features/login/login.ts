import { Component } from '@angular/core';
import { Auth } from '../../core/auth/auth';

@Component({
  selector: 'app-login',
  standalone: true,
  template: `
    <div style="text-align: center; padding: 40px;">
      <h2>Login</h2>
      <button 
        type="button" 
        (click)="login()"
        [disabled]="isLoading"
        style="padding: 10px 20px; font-size: 16px; cursor: pointer;"
      >
        {{ isLoading ? '⏳ Redirecting to Cognito...' : '🔐 LOGIN' }}
      </button>
    </div>
  `,
})
export class Login {
  isLoading = false;

  constructor(private auth: Auth) { }

  async login(): Promise<void> {
    this.isLoading = true;
    try {
      await this.auth.login();
    } catch (error) {
      this.isLoading = false;
      console.error('Login error:', error);
    }
  }
}