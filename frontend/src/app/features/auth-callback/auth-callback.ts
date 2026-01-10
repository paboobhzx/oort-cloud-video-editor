import { Component, OnInit } from '@angular/core';
import { Router, ActivatedRoute } from '@angular/router';
import { Auth } from '../../core/auth/auth';

@Component({
  selector: 'app-auth-callback',
  template: `
    <div style="text-align: center; padding: 40px;">
      <h2>Processing login...</h2>
      <p *ngIf="!error">⏳ Please wait while we complete your authentication.</p>
      <p *ngIf="error" style="color: red;">❌ {{ error }}</p>
    </div>
  `,
  standalone: true,
})
export class AuthCallback implements OnInit {
  error = '';

  constructor(
    private auth: Auth,
    private router: Router,
    private route: ActivatedRoute
  ) { }

  async ngOnInit(): Promise<void> {
    try {
      console.log('🔐 AuthCallback initialized');

      // Check for authorization code in URL
      const code = this.route.snapshot.queryParamMap.get('code');
      const errorParam = this.route.snapshot.queryParamMap.get('error');

      if (errorParam) {
        const errorDescription = this.route.snapshot.queryParamMap.get('error_description');
        throw new Error(`Cognito error: ${errorParam} - ${errorDescription}`);
      }

      if (!code) {
        throw new Error('No authorization code received from Cognito');
      }

      console.log('✅ Authorization code received:', code.substring(0, 20) + '...');

      // Exchange code for tokens
      await this.auth.exchangeCodeForTokens(code);

      console.log('✅ Successfully authenticated. Redirecting to upload...');
      this.router.navigate(['/upload']);
    } catch (err: any) {
      console.error('❌ Authentication failed:', err);
      this.error = err.message || 'Authentication failed. Please try again.';

      // Redirect to login after 3 seconds
      setTimeout(() => {
        this.router.navigateByUrl('/login');
      }, 3000);
    }
  }
}