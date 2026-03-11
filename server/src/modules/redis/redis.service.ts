import { Inject, Injectable } from '@nestjs/common';
import type { RedisClientType } from 'redis';
import { REDIS_CLIENT } from './redis.constants';

@Injectable()
export class RedisService {
  constructor(
    @Inject(REDIS_CLIENT) private readonly client: RedisClientType,
  ) {}

  getClient(): RedisClientType {
    return this.client;
  }
}

