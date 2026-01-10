// environments/environment.ts - LOCALHOST DEVELOPMENT
export const environment = {
    production: false,

    // OAuth/Authentication config
    cognito: {
        domain: 'oort-cloud-video-editor-dev-j85pkfhu.auth.us-east-1.amazoncognito.com',
        clientId: '7o3set8aj3s01q75rnn65qr7gi',
        // ✅ Use localhost for development
        redirecturi: 'http://localhost:4200/auth-callback',
        scope: 'openid profile email',
        logoutUri: 'http://localhost:4200/login',
    },

    // API config - Points to cloud
    api: {
        baseUrl: 'https://4b089or4kj.execute-api.us-east-1.amazonaws.com',
    },
};