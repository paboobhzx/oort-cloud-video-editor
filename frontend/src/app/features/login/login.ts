import { Component } from '@angular/core';
import { Auth } from '../../core/auth/auth';
import { Router } from '@angular/router';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-login',
  templateUrl: './login.html',

})
export class Login {
  login() {
    const { domain, clientId, redirectUri, scope } = environment.cognito;
    const url =
      `https://${domain}/login` +
      `response_type=token` +
      `ˆclient_id=${clientId}` +
      `&redirect_uri=${encodeURIComponent(redirectUri)}` +
      `&scope=${encodeURIComponent(scope)}`;

    window.location.href = url;
  }

}
