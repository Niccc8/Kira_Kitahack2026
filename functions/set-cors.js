/**
 * Set CORS on Firebase Storage bucket using GCS REST API
 * with the Firebase CLI's stored access token.
 * 
 * Run from functions/:  node set-cors.js
 */
const path = require('path');
const os = require('os');
const fs = require('fs');
const https = require('https');

const BUCKET = 'kira26.firebasestorage.app';

// Get access token from Firebase CLI config
function getAccessToken() {
    const paths = [
        path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
        path.join(os.homedir(), 'AppData', 'Roaming', 'configstore', 'firebase-tools.json'),
    ];

    for (const configPath of paths) {
        try {
            if (fs.existsSync(configPath)) {
                const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
                const token = config.tokens?.access_token;
                if (token) {
                    console.log(`📌 Found access token in ${configPath}`);
                    return token;
                }
                // If no access token, try refresh token to get one
                const refreshToken = config.tokens?.refresh_token;
                if (refreshToken) {
                    console.log(`📌 Found refresh token, will exchange for access token`);
                    return refreshToken; // We'll use refresh flow
                }
            }
        } catch (e) {
            // continue
        }
    }
    return null;
}

// Exchange refresh token for access token
function refreshAccessToken(refreshToken) {
    return new Promise((resolve, reject) => {
        const data = new URLSearchParams({
            grant_type: 'refresh_token',
            refresh_token: refreshToken,
            client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
            client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
        }).toString();

        const req = https.request({
            hostname: 'oauth2.googleapis.com',
            path: '/token',
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Content-Length': Buffer.byteLength(data),
            },
        }, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(body);
                    if (json.access_token) {
                        resolve(json.access_token);
                    } else {
                        reject(new Error(body));
                    }
                } catch (e) {
                    reject(e);
                }
            });
        });
        req.on('error', reject);
        req.write(data);
        req.end();
    });
}

// Set CORS via GCS JSON API
function setCors(accessToken) {
    return new Promise((resolve, reject) => {
        const corsConfig = {
            cors: [
                {
                    origin: ['*'],
                    method: ['GET', 'HEAD', 'PUT', 'POST', 'DELETE'],
                    maxAgeSeconds: 3600,
                    responseHeader: [
                        'Content-Type',
                        'Content-Length',
                        'Content-Range',
                        'x-goog-resumable',
                    ],
                },
            ],
        };

        const data = JSON.stringify(corsConfig);

        const req = https.request({
            hostname: 'storage.googleapis.com',
            path: `/storage/v1/b/${BUCKET}?fields=cors`,
            method: 'PATCH',
            headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(data),
            },
        }, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                if (res.statusCode === 200) {
                    console.log('✅ CORS configured successfully for', BUCKET);
                    console.log(body);
                    resolve();
                } else {
                    reject(new Error(`HTTP ${res.statusCode}: ${body}`));
                }
            });
        });
        req.on('error', reject);
        req.write(data);
        req.end();
    });
}

async function main() {
    console.log('🔐 Getting credentials...');

    // Read Firebase CLI config to find refresh token
    const paths = [
        path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
        path.join(os.homedir(), 'AppData', 'Roaming', 'configstore', 'firebase-tools.json'),
    ];

    let refreshToken = null;
    for (const configPath of paths) {
        try {
            if (fs.existsSync(configPath)) {
                const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
                refreshToken = config.tokens?.refresh_token;
                if (refreshToken) {
                    console.log(`📌 Found refresh token in ${configPath}`);
                    break;
                }
            }
        } catch (e) { /* continue */ }
    }

    if (!refreshToken) {
        console.error('❌ No Firebase CLI credentials found. Run: firebase login');
        process.exit(1);
    }

    console.log('🔄 Exchanging refresh token for access token...');
    const accessToken = await refreshAccessToken(refreshToken);
    console.log('✅ Got access token');

    console.log('📡 Setting CORS on bucket:', BUCKET);
    await setCors(accessToken);
    process.exit(0);
}

main().catch(err => {
    console.error('❌', err.message);
    process.exit(1);
});
