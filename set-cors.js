/**
 * Set CORS on the Firebase Storage bucket via firebase-admin.
 * Run from the functions/ directory: node ../set-cors.js
 */

const admin = require('firebase-admin');

// Initialize the admin SDK — uses Application Default Credentials
admin.initializeApp({
    storageBucket: 'kira26.firebasestorage.app',
});

async function main() {
    const bucket = admin.storage().bucket();

    const corsConfig = [
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
    ];

    try {
        await bucket.setCorsConfiguration(corsConfig);
        console.log('✅ CORS configured successfully for', bucket.name);
        console.log(JSON.stringify(corsConfig, null, 2));
    } catch (err) {
        console.error('❌ Failed to set CORS:', err.message);
        console.log('\n💡 Alternative: Install Google Cloud SDK and run:');
        console.log(`   gsutil cors set cors.json gs://${bucket.name}`);
        process.exit(1);
    }
}

main();
