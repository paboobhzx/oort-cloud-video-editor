export const environment = {
    production: false,

    cognito: {
        domain: 'oort-cloud-video-editor-dev-v9angwk5.auth.us-east-1.amazoncognito.com',
        clientId: '3vgrb0d9jv06a3el9tarhtsb0o',  // ✅ NEW ID
        redirecturi: 'http://localhost:4200/auth-callback',
        scope: 'openid profile email',
        logoutUri: 'http://localhost:4200/login',
    },

    api: {
        baseUrl: 'https://cx3py4x836.execute-api.us-east-1.amazonaws.com'
    }
};