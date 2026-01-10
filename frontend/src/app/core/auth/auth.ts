import { Injectable } from '@angular/core';
import { environment } from '../../../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class Auth {
  private readonly TOKEN_KEY = 'access_token';
  private readonly ID_TOKEN_KEY = 'id_token';
  private readonly REFRESH_TOKEN_KEY = 'refresh_token';
  private readonly CODE_VERIFIER_KEY = 'pkce_code_verifier';
  private readonly STATE_KEY = 'pkce_state';

  /**
   * Generate PKCE code verifier (43-128 characters)
   */
  private generateCodeVerifier(): string {
    console.log('🔧 Generating code verifier...');
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    const verifier = btoa(String.fromCharCode.apply(null, Array.from(array)))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
    console.log('✅ Code verifier generated, length:', verifier.length);
    return verifier;
  }

  /**
   * Generate random state parameter
   */
  private generateState(): string {
    console.log('🔧 Generating state...');
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    const state = btoa(String.fromCharCode.apply(null, Array.from(array)))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
    console.log('✅ State generated, length:', state.length);
    return state;
  }

  /**
   * Generate PKCE code challenge
   */
  private async generateCodeChallenge(verifier: string): Promise<string> {
    console.log('🔧 Generating code challenge from verifier...');
    try {
      const encoder = new TextEncoder();
      const data = encoder.encode(verifier);
      const digest = await crypto.subtle.digest('SHA-256', data);
      const challenge = btoa(String.fromCharCode.apply(null, Array.from(new Uint8Array(digest))))
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '');
      console.log('✅ Code challenge generated, length:', challenge.length);
      return challenge;
    } catch (error) {
      console.error('❌ Failed to generate code challenge:', error);
      throw error;
    }
  }

  /**
   * Build login URL
   */
  async buildLoginUrl(): Promise<string> {
    console.log('🔐 Building login URL...');

    try {
      const config = (environment as any).cognito;
      console.log('📋 Cognito config:', {
        domain: config?.domain,
        clientId: config?.clientId,
        redirectUri: config?.redirecturi,
        scope: config?.scope,
      });

      if (!config?.domain || !config?.clientId || !config?.redirecturi) {
        throw new Error('Invalid Cognito configuration: missing domain, clientId, or redirecturi');
      }

      const { domain, clientId, redirecturi, scope } = config;

      // Generate PKCE
      const codeVerifier = this.generateCodeVerifier();
      const codeChallenge = await this.generateCodeChallenge(codeVerifier);
      const state = this.generateState();

      console.log('💾 Storing PKCE parameters in localStorage...');
      localStorage.setItem(this.CODE_VERIFIER_KEY, codeVerifier);
      localStorage.setItem(this.STATE_KEY, state);
      console.log('✅ Stored code verifier:', localStorage.getItem(this.CODE_VERIFIER_KEY) ? 'YES' : 'NO');
      console.log('✅ Stored state:', localStorage.getItem(this.STATE_KEY) ? 'YES' : 'NO');

      // Build URL
      const params = new URLSearchParams({
        response_type: 'code',
        client_id: clientId,
        redirect_uri: redirecturi,
        scope,
        code_challenge: codeChallenge,
        code_challenge_method: 'S256',
        state,
      });

      const loginUrl = `https://${domain}/oauth2/authorize?${params.toString()}`;
      console.log('✅ Login URL built:', loginUrl.substring(0, 100) + '...');
      return loginUrl;
    } catch (error) {
      console.error('❌ Error building login URL:', error);
      throw error;
    }
  }

  /**
   * Start login flow
   */
  async login(): Promise<void> {
    console.log('🔐 Login button clicked');
    try {
      console.log('🔄 Building login URL...');
      const loginUrl = await this.buildLoginUrl();
      console.log('✅ Login URL ready');

      console.log('📤 Redirecting to Cognito...');
      window.location.assign(loginUrl);
    } catch (error) {
      console.error('❌ Login error:', error);
      alert('Login failed: ' + (error instanceof Error ? error.message : String(error)));
    }
  }

  /**
   * Exchange code for tokens
   */
  async exchangeCodeForTokens(code: string): Promise<void> {
    try {
      const config = (environment as any).cognito;
      const codeVerifier = localStorage.getItem(this.CODE_VERIFIER_KEY);

      if (!codeVerifier) {
        throw new Error('Code verifier not found');
      }

      const tokenUrl = `https://${config.domain}/oauth2/token`;

      console.log('🔄 Exchanging code for tokens...');

      const response = await fetch(tokenUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          client_id: config.clientId,
          code,
          redirect_uri: config.redirecturi,
          code_verifier: codeVerifier,
        }).toString(),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(`Token exchange failed: ${error.error_description || error.error}`);
      }

      const data = await response.json();
      console.log('✅ Token response received');

      if (data.id_token) {
        localStorage.setItem(this.ID_TOKEN_KEY, data.id_token);
        console.log('✅ ID token saved');
      }

      if (data.access_token) {
        localStorage.setItem(this.TOKEN_KEY, data.access_token);
        console.log('✅ Access token saved');
      }

      if (data.refresh_token) {
        localStorage.setItem(this.REFRESH_TOKEN_KEY, data.refresh_token);
        console.log('✅ Refresh token saved');
      }

      localStorage.removeItem(this.CODE_VERIFIER_KEY);
      localStorage.removeItem(this.STATE_KEY);

      console.log('✅ Tokens obtained successfully');
    } catch (error) {
      console.error('❌ Token exchange failed:', error);
      throw error;
    }
  }

  getToken(): string | null {
    return localStorage.getItem(this.TOKEN_KEY);
  }

  getIdToken(): string | null {
    return localStorage.getItem(this.ID_TOKEN_KEY);
  }

  isAuthenticated(): boolean {
    return !!(this.getToken() || this.getIdToken());
  }

  clearTokens(): void {
    localStorage.removeItem(this.TOKEN_KEY);
    localStorage.removeItem(this.ID_TOKEN_KEY);
    localStorage.removeItem(this.REFRESH_TOKEN_KEY);
    localStorage.removeItem(this.CODE_VERIFIER_KEY);
    localStorage.removeItem(this.STATE_KEY);
    console.log('✅ All tokens cleared');
  }

  logout(): void {
    try {
      const config = (environment as any).cognito;

      if (!config?.domain || !config?.clientId || !config?.logoutUri) {
        console.error('❌ Missing logout configuration');
        return;
      }

      const { domain, clientId, logoutUri } = config;

      const params = new URLSearchParams({
        client_id: clientId,
        logout_uri: logoutUri,
      });

      this.clearTokens();

      console.log('🔗 Navigating to Cognito logout...');
      window.location.assign(`https://${domain}/logout?${params.toString()}`);
    } catch (error) {
      console.error('❌ Logout failed:', error);
    }
  }
}