import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PathPoint } from './run.entity';
import { Run } from './run.entity';
import { User } from '../users/user.entity';

@Injectable()
export class RunsService {
  constructor(
    @InjectRepository(Run)
    private readonly runRepo: Repository<Run>,
  ) {}

  async create(user: User, path: PathPoint[]): Promise<Run> {
    if (!path.length) {
      throw new Error('Path cannot be empty');
    }
    const startedAt = new Date(path[0].t);
    const endedAt = new Date(path[path.length - 1].t);
    const run = this.runRepo.create({
      userId: user.id,
      startedAt,
      endedAt,
      path,
    });
    return this.runRepo.save(run);
  }

  async findByUser(userId: string): Promise<Run[]> {
    return this.runRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }
}
