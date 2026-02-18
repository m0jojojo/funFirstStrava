import { Injectable } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';
import JwksRsa from 'jwks-rsa';

/** Verified Firebase ID token payload (relevant claims). */
export interface FirebaseTokenPayload {
  sub: string;
  email?: string;
  name?: string;
}

/**
 * Verifies Firebase ID tokens using Google's JWKS.
 * Requires FIREBASE_PROJECT_ID in env. No service account file needed.
 */
@Injectable()
export class FirebaseTokenService {
  private _projectId: string | null = null;
  private _jwksClient: JwksRsa.JwksClient | null = null;

  private get projectId(): string {
    if (!this._projectId) {
      const id = process.env.FIREBASE_PROJECT_ID;
      if (!id) throw new Error('FIREBASE_PROJECT_ID is required for token verification');
      this._projectId = id;
    }
    return this._projectId;
  }

  private get jwksClient(): JwksRsa.JwksClient {
    if (!this._jwksClient) {
      this._jwksClient = JwksRsa({
        jwksUri: 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
        cache: true,
        cacheMaxAge: 600000,
      });
    }
    return this._jwksClient;
  }

  async verifyIdToken(idToken: string): Promise<FirebaseTokenPayload> {
    const decoded = jwt.decode(idToken, { complete: true });
    if (!decoded || typeof decoded === 'string' || !decoded.header?.kid) {
      throw new Error('Invalid token format');
    }
    const key = await this.jwksClient.getSigningKey(decoded.header.kid);
    const publicKey = key.getPublicKey();
    const pid = this.projectId;
    const payload = jwt.verify(idToken, publicKey, {
      algorithms: ['RS256'],
      audience: pid,
      issuer: `https://securetoken.google.com/${pid}`,
    }) as jwt.JwtPayload;
    const sub = payload.sub;
    if (typeof sub !== 'string') throw new Error('Invalid token: missing sub');
    return {
      sub,
      email: payload.email ?? undefined,
      name: (payload.name as string | undefined) ?? payload.email?.split('@')[0],
    };
  }
}
