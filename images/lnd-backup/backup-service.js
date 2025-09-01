#!/usr/bin/env node

const fs = require('fs');
const { subscribeToBackups, authenticatedLndGrpc } = require('lightning');

// Configuration from environment variables
const NETWORK = process.env.NETWORK || 'mainnet';
const LND_DIR = '/root/.lnd';
const TLS_CERT_PATH = `${LND_DIR}/tls.cert`;
const MACAROON_PATH = `${LND_DIR}/data/chain/bitcoin/${NETWORK}/admin.macaroon`;
const CHANNEL_BACKUP_PATH = `${LND_DIR}/data/chain/bitcoin/${NETWORK}/channel.backup`;

// Backup configuration
const GCS_ENABLED = process.env.GCS_ENABLED === 'true';
const GCS_BUCKET = process.env.GCS_BUCKET;
const S3_ENABLED = process.env.S3_ENABLED === 'true';
const S3_BUCKET = process.env.S3_BUCKET;
const S3_REGION = process.env.AWS_DEFAULT_REGION || 'us-east-1';
const NEXTCLOUD_ENABLED = process.env.NEXTCLOUD_ENABLED === 'true';
const NEXTCLOUD_URL = process.env.NEXTCLOUD_URL;

let pubkey = null;

// Function to read and upload channel backup file
async function uploadChannelBackupFile() {
  try {
    if (!fs.existsSync(CHANNEL_BACKUP_PATH)) {
      console.log('No channel backup file found');
      return;
    }

    const backupData = fs.readFileSync(CHANNEL_BACKUP_PATH);
    if (backupData.length === 0) {
      console.log('Channel backup file is empty');
      return;
    }

    console.log(`Reading channel backup file (${backupData.length} bytes)`);
    await uploadBackup(backupData.toString('hex'));
    console.log('Channel backup uploaded successfully');
  } catch (error) {
    console.error('Error uploading channel backup file:', error.message);
  }
}

// Wait for LND to be ready
async function waitForLnd() {
  console.log('Waiting for LND to be ready...');
  
  while (true) {
    try {
      // Check if TLS cert and macaroon exist
      if (!fs.existsSync(TLS_CERT_PATH) || !fs.existsSync(MACAROON_PATH)) {
        console.log('LND credentials not ready, waiting...');
        await new Promise(resolve => setTimeout(resolve, 5000));
        continue;
      }

      // Try to connect to LND
      const { lnd } = authenticatedLndGrpc({
        cert: fs.readFileSync(TLS_CERT_PATH),
        macaroon: fs.readFileSync(MACAROON_PATH),
        socket: 'localhost:10009'
      });

      // Test connection by getting node info
      const { getWalletInfo } = require('lightning');
      const info = await getWalletInfo({ lnd });
      pubkey = info.public_key;
      console.log(`LND ready. Node pubkey: ${pubkey}`);
      return lnd;
    } catch (error) {
      console.log('LND not ready, waiting...', error.message);
      await new Promise(resolve => setTimeout(resolve, 5000));
    }
  }
}

// Upload backup to configured destinations
async function uploadBackup(backupData) {
  const timestamp = Math.floor(Date.now() / 1000);
  const filename = `${NETWORK}_lnd_scb_${pubkey}_${timestamp}`;
  
  console.log(`Uploading backup: ${filename}`);

  const promises = [];

  // Upload to Google Cloud Storage
  if (GCS_ENABLED && GCS_BUCKET) {
    promises.push(uploadToGCS(backupData, filename));
  }

  // Upload to AWS S3
  if (S3_ENABLED && S3_BUCKET) {
    promises.push(uploadToS3(backupData, filename));
  }

  // Upload to Nextcloud
  if (NEXTCLOUD_ENABLED && NEXTCLOUD_URL) {
    promises.push(uploadToNextcloud(backupData, filename));
  }

  if (promises.length === 0) {
    console.log('No backup destinations configured');
    return;
  }

  try {
    await Promise.allSettled(promises);
    console.log('Backup upload completed');
  } catch (error) {
    console.error('Error during backup upload:', error);
  }
}

async function uploadToGCS(backupData, filename) {
  try {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      throw new Error('GCS credentials not configured');
    }

    console.log('Uploading to Google Cloud Storage...');
    
    // Authenticate with service account
    execSync('gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS', { stdio: 'inherit' });
    
    // Upload backup
    const tempFile = `/tmp/${filename}`;
    fs.writeFileSync(tempFile, backupData);
    execSync(`gsutil cp ${tempFile} gs://${GCS_BUCKET}/lnd_scb/${filename}`, { stdio: 'inherit' });
    fs.unlinkSync(tempFile);
    
    console.log('Successfully uploaded to GCS');
  } catch (error) {
    console.error('Failed to upload to GCS:', error.message);
    throw error;
  }
}

async function uploadToS3(backupData, filename) {
  try {
    if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
      throw new Error('AWS credentials not configured');
    }

    // Auto-detect MinIO by checking for MinIO service environment variables
    let s3Endpoint = process.env.S3_ENDPOINT;
    if (!s3Endpoint && process.env.MINIO_SERVICE_HOST) {
      s3Endpoint = `http://${process.env.MINIO_SERVICE_HOST}:${process.env.MINIO_SERVICE_PORT || 9000}`;
    }

    const uploadTarget = s3Endpoint ? 'MinIO' : 'AWS S3';
    console.log(`Uploading to ${uploadTarget}...`);

    // Use AWS SDK v3
    const { S3Client } = require('@aws-sdk/client-s3');
    const { Upload } = require('@aws-sdk/lib-storage');

    const s3Config = {
      credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      },
      region: S3_REGION,
      forcePathStyle: true // Required for MinIO
    };

    if (s3Endpoint) {
      s3Config.endpoint = s3Endpoint;
    }

    const s3Client = new S3Client(s3Config);

    const uploadParams = {
      Bucket: S3_BUCKET,
      Key: `lnd_scb/${filename}`,
      Body: backupData,
      ContentType: 'application/octet-stream'
    };

    const upload = new Upload({
      client: s3Client,
      params: uploadParams,
    });

    await upload.done();

    console.log(`Successfully uploaded to ${uploadTarget}`);
  } catch (error) {
    console.error('Failed to upload to S3:', error.message);
    throw error;
  }
}

async function uploadToNextcloud(backupData, filename) {
  try {
    if (!process.env.NEXTCLOUD_USER || !process.env.NEXTCLOUD_PASSWORD) {
      throw new Error('Nextcloud credentials not configured');
    }

    console.log('Uploading to Nextcloud...');

    // Use HTTP request instead of curl
    const https = require('https');
    const http = require('http');
    const url = require('url');

    const uploadUrl = `${NEXTCLOUD_URL}/${filename}`;
    const parsedUrl = url.parse(uploadUrl);
    const isHttps = parsedUrl.protocol === 'https:';

    const auth = Buffer.from(`${process.env.NEXTCLOUD_USER}:${process.env.NEXTCLOUD_PASSWORD}`).toString('base64');

    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || (isHttps ? 443 : 80),
      path: parsedUrl.path,
      method: 'PUT',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/octet-stream',
        'Content-Length': Buffer.byteLength(backupData)
      }
    };

    return new Promise((resolve, reject) => {
      const req = (isHttps ? https : http).request(options, (res) => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log('Successfully uploaded to Nextcloud');
          resolve();
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${res.statusMessage}`));
        }
      });

      req.on('error', reject);
      req.write(backupData);
      req.end();
    });

  } catch (error) {
    console.error('Failed to upload to Nextcloud:', error.message);
    throw error;
  }
}

// Main backup service
async function startBackupService() {
  try {
    console.log('Starting LND SCB backup service...');
    
    // Wait for LND to be ready
    const lnd = await waitForLnd();
    
    // Subscribe to backup events
    console.log('Subscribing to backup events...');
    const sub = subscribeToBackups({ lnd });
    
    sub.on('backup', async () => {
      console.log('Backup event received');
      try {
        // Upload the channel backup file directly
        await uploadChannelBackupFile();
      } catch (error) {
        console.error('Error handling backup event:', error);
      }
    });
    
    sub.on('error', (error) => {
      console.error('Backup subscription error:', error);
      // Restart the service after a delay
      setTimeout(() => {
        console.log('Restarting backup service...');
        startBackupService();
      }, 10000);
    });
    
    console.log('Backup service started successfully');
    
    // Create initial backup if channel backup file exists
    try {
      console.log('Checking for existing channel backup...');
      await uploadChannelBackupFile();
    } catch (error) {
      console.log('Could not create initial backup:', error.message);
    }
    
  } catch (error) {
    console.error('Failed to start backup service:', error);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully...');
  process.exit(0);
});

// Start the service
startBackupService();
