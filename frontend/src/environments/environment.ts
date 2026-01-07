export const environment = {
    production: false,

    cognito: {
        domain: 'oort-cloud-video-editor-dev-j85pkfhu.auth.us-east-1.amazoncognito.com',
        clientId: '7o3set8aj3s01q75rnn65qr7gi',
        redirectUri: 'http://localhost:4200/auth/callback',
        logoutUri: 'http://localhost:4200/login',
        scope: 'openid email profile',
    },

};
