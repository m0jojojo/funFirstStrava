import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import { FirebaseTokenService } from './firebase-token.service';
import { User } from './user.entity';
import { UsersService } from './users.service';

export const REQUEST_USER_KEY = 'user';

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(
    private readonly firebaseToken: FirebaseTokenService,
    private readonly usersService: UsersService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const auth = request.headers.authorization;
    if (!auth?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid Authorization header');
    }
    const idToken = auth.slice(7).trim();
    const payload = await this.firebaseToken.verifyIdToken(idToken);
    const user = await this.usersService.findByFirebaseUid(payload.sub);
    if (!user) {
      throw new UnauthorizedException('User not registered');
    }
    (request as Request & { user: User }).user = user;
    return true;
  }
}
