import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as admin from 'firebase-admin';

/**
 * Sends push notifications via Firebase Cloud Messaging.
 * Requires FIREBASE_SERVICE_ACCOUNT_JSON (raw JSON) or GOOGLE_APPLICATION_CREDENTIALS (path to file).
 * If not configured, sends are no-ops (logs warning).
 */
@Injectable()
export class PushNotificationService implements OnModuleInit {
  private readonly logger = new Logger(PushNotificationService.name);
  private initialized = false;

  onModuleInit(): void {
    if (admin.apps.length > 0) {
      this.initialized = true;
      this.logger.log('Firebase Admin already initialized');
      return;
    }
    const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (json) {
      try {
        const cred = JSON.parse(json) as admin.ServiceAccount;
        admin.initializeApp({ credential: admin.credential.cert(cred) });
        this.initialized = true;
        this.logger.log('Firebase Admin initialized from FIREBASE_SERVICE_ACCOUNT_JSON');
      } catch (e) {
        this.logger.warn('Invalid FIREBASE_SERVICE_ACCOUNT_JSON, push notifications disabled');
      }
    } else if (credPath) {
      try {
        admin.initializeApp({ credential: admin.credential.applicationDefault() });
        this.initialized = true;
        this.logger.log('Firebase Admin initialized from GOOGLE_APPLICATION_CREDENTIALS');
      } catch (e) {
        this.logger.warn('Failed to initialize Firebase Admin from GOOGLE_APPLICATION_CREDENTIALS, push notifications disabled');
      }
    } else {
      this.logger.warn('No FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS, push notifications disabled');
    }
  }

  /**
   * Send a notification to a single FCM token. Fire-and-forget; errors are logged.
   */
  async sendToToken(token: string, title: string, body: string, data?: Record<string, string>): Promise<void> {
    if (!this.initialized) return;
    const message: admin.messaging.Message = {
      token,
      notification: { title, body },
      data: data ?? {},
      android: { priority: 'high' },
    };
    try {
      await admin.messaging().send(message);
      this.logger.debug(`FCM sent to token ${token.slice(0, 20)}...`);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.warn(`FCM send failed: ${msg} (token ${token.slice(0, 20)}...)`);
    }
  }

  /**
   * Send the same notification to multiple tokens. Runs in parallel; each failure is logged.
   */
  async sendToTokens(tokens: string[], title: string, body: string, data?: Record<string, string>): Promise<void> {
    const valid = tokens.filter((t) => t && t.trim().length > 0);
    if (valid.length === 0) return;
    await Promise.all(valid.map((token) => this.sendToToken(token, title, body, data)));
  }
}
