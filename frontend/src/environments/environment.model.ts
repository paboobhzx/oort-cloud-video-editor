export interface CognitoConfig {
    domain: string;
    clientId: string;
    redirecturi: string;
    logoutUri: string;
    scope: string;
}
export interface Environment {
    production: boolean;
    apiBaseUrl: string;
    cognito: CognitoConfig;
}