import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { Auth } from '../../core/auth/auth';

@Component({
  selector: 'app-auth-callback',
  imports: [],
  templateUrl: './auth-callback.html',
  styleUrl: './auth-callback.scss',
})
export class AuthCallback implements OnInit {
  constructor(
    private auth: Auth,
    private router: Router

  ) { }
  ngOnInit() {

    const hash = window.location.hash.substring(1);

    const params = new URLSearchParams(hash);
    const accessToken = params.get('access_token')

    if (accessToken) {
      this.auth.setToken(accessToken);
      this.router.navigate(['/uploadf']);
    }
    else {
      this.router.navigate(['/login']);
    }
  }

}


