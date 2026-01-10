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

  /**
   * Generate PKCE code verifier (43-128 characters)
   */
  private generateCodeVerifier(): string {
    const array = new Uint8Array(32);
    crypto.getRandomValues(array);
    return btoa(String.fromCharCode.apply(null, Array.from(array)))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  }

  /**
   * Generate PKCE code challenge from verifier
   */
  private async generateCodeChallenge(verifier: string): Promise<string> {
    const encoder = new TextEncoder();
    const data = encoder.encode(verifier);
    const digest = await crypto.subtle.digest('SHA-256', data);
    return btoa(String.fromCharCode.apply(null, Array.from(new Uint8Array(digest))))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  }

  /**
   * Builds the Cognito authorization URL using Authorization Code Grant
   */
  async buildLoginUrl(): Promise<string> {
    const config = (environment as any).cognito;

    if (!config?.domain || !config?.clientId || !config?.redirecturi) {
      throw new Error('Invalid Cognito configuration');
    }

    const { domain, clientId, redirecturi, scope } = config;

    // Generate PKCE parameters
    const codeVerifier = this.generateCodeVerifier();
    const codeChallenge = await this.generateCodeChallenge(codeVerifier);

    // Store code verifier for later use (when exchanging code for tokens)
    localStorage.setItem(this.CODE_VERIFIER_KEY, codeVerifier);

    const params = new URLSearchParams({
      response_type: 'code', // ✅ Changed from 'token' to 'code'
      client_id: clientId,
      redirect_uri: redirecturi,
      scope,
      code_challenge: codeChallenge,
      code_challenge_method: 'S256', // SHA-256
    });

    return `https://${domain}/oauth2/authorize?${params.toString()}`;
  }

  /**
   * Starts the Cognito login flow
   */
  async login(): Promise<void> {
    try {
      const loginUrl = await this.buildLoginUrl();
      console.log('✅ Login URL built successfully');

      setTimeout(() => {
        console.log('🔗 Navigating to Cognito...');
        window.location.assign(loginUrl);
      }, 0);
    } catch (error) {
      console.error('❌ Login failed:', error);
      alert('Login configuration error. Check console for details.');
    }
  }

  /**
   * Exchange authorization code for tokens
   * This is called after Cognito redirects back with the 'code' parameter
   */
  async exchangeCodeForTokens(code: string): Promise<void> {
    try {
      const config = (environment as any).cognito;
      const codeVerifier = localStorage.getItem(this.CODE_VERIFIER_KEY);

      if (!codeVerifier) {
        throw new Error('Code verifier not found. Login may have been interrupted.');
      }

      const tokenUrl = `https://${config.domain}/oauth2/token`;

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

      // Store tokens
      if (data.access_token) {
        this.setToken(data.access_token);
      }
      if (data.id_token) {
        localStorage.setItem(this.ID_TOKEN_KEY, data.id_token);
      }
      if (data.refresh_token) {
        localStorage.setItem(this.REFRESH_TOKEN_KEY, data.refresh_token);
      }

      // Clean up code verifier
      localStorage.removeItem(this.CODE_VERIFIER_KEY);

      console.log('✅ Tokens obtained successfully');
    } catch (error) {
      console.error('❌ Token exchange failed:', error);
      throw error;
    }
  }

  /**
   * Persist access token
   */
  setToken(token: string): void {
    try {
      localStorage.setItem(this.TOKEN_KEY, token);
      console.log('✅ Access token saved to localStorage');
    } catch (error) {
      console.error('❌ Failed to save token:', error);
    }
  }

  /**
   * Retrieve stored access token
   */
  getToken(): string | null {
    try {
      return localStorage.getItem(this.TOKEN_KEY);
    } catch (error) {
      console.error('❌ Failed to retrieve token:', error);
      return null;
    }
  }

  /**
   * Retrieve stored ID token
   */
  getIdToken(): string | null {
    try {
      return localStorage.getItem(this.ID_TOKEN_KEY);
    } catch (error) {
      console.error('❌ Failed to retrieve ID token:', error);
      return null;
    }
  }

  /**
   * Check authentication status
   */
  isAuthenticated(): boolean {
    return !!this.getToken();
  }

  /**
   * Clear all tokens
   */
  clearTokens(): void {
    try {
      localStorage.removeItem(this.TOKEN_KEY);
      localStorage.removeItem(this.ID_TOKEN_KEY);
      localStorage.removeItem(this.REFRESH_TOKEN_KEY);
      localStorage.removeItem(this.CODE_VERIFIER_KEY);
      console.log('✅ All tokens cleared');
    } catch (error) {
      console.error('❌ Failed to clear tokens:', error);
    }
  }

  /**
   * Logout via Cognito Hosted UI
   */
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

      setTimeout(() => {
        console.log('🔗 Navigating to Cognito logout...');
        window.location.assign(`https://${domain}/logout?${params.toString()}`);
      }, 0);
    } catch (error) {
      console.error('❌ Logout failed:', error);
    }
  }
}