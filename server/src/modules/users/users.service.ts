import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { FirebaseTokenService } from './firebase-token.service';
import { User } from './user.entity';
import { IUsersService, RegisterResult } from './users.service.interface';

@Injectable()
export class UsersService implements IUsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly firebaseToken: FirebaseTokenService,
  ) {}

  async register(idToken: string, displayName?: string, email?: string): Promise<RegisterResult> {
    const payload = await this.firebaseToken.verifyIdToken(idToken);
    const firebaseUid = payload.sub;
    const username = displayName ?? payload.name ?? payload.email ?? firebaseUid.slice(0, 8);

    const existing = await this.userRepo.findOne({ where: { firebaseUid } });
    if (existing) {
      existing.username = username;
      await this.userRepo.save(existing);
      return { user: existing, created: false };
    }
    const user = this.userRepo.create({
      firebaseUid,
      username,
    });
    await this.userRepo.save(user);
    return { user, created: true };
  }

  async findByFirebaseUid(firebaseUid: string): Promise<User | null> {
    return this.userRepo.findOne({ where: { firebaseUid } });
  }

  async findByIds(ids: string[]): Promise<User[]> {
    if (ids.length === 0) return [];
    return this.userRepo.find({ where: { id: In(ids) } });
  }
}
