import { Inject, Injectable, Logger } from '@nestjs/common';
import type { RedisClientType } from 'redis';
import { REDIS_CLIENT } from '../redis/redis.constants';

export type LeaderboardScope =
  | { type: 'global' }
  | { type: 'country'; countryCode: string }
  | { type: 'city'; cityName: string };

@Injectable()
export class LeaderboardService {
  private readonly logger = new Logger(LeaderboardService.name);

  constructor(
    @Inject(REDIS_CLIENT) private readonly redis: RedisClientType,
  ) {}

  private getKey(scope: LeaderboardScope): string {
    switch (scope.type) {
      case 'global':
        return 'leaderboard:global';
      case 'country': {
        const code = scope.countryCode.trim().toUpperCase();
        return `leaderboard:country:${code}`;
      }
      case 'city': {
        const normalized = scope.cityName.trim().toLowerCase().replace(/\s+/g, '_');
        return `leaderboard:city:${normalized}`;
      }
      default:
        // Should never happen, but keeps TypeScript happy if scope is widened.
        this.logger.warn(`Unknown leaderboard scope ${(scope as any).type}`);
        return 'leaderboard:global';
    }
  }

  async incrementScore(
    userId: string,
    amount: number,
    scope: LeaderboardScope,
  ): Promise<number> {
    const key = this.getKey(scope);
    const newScore = await this.redis.zIncrBy(key, amount, userId);
    return typeof newScore === 'number' ? newScore : Number(newScore);
  }

  async getScoreAndRank(
    userId: string,
    scope: LeaderboardScope,
  ): Promise<{ score: number | null; rank: number | null }> {
    const key = this.getKey(scope);
    const [scoreRaw, rankRaw] = await Promise.all([
      this.redis.zScore(key, userId),
      this.redis.zRevRank(key, userId),
    ]);
    if (scoreRaw === null || rankRaw === null || rankRaw === undefined) {
      return { score: null, rank: null };
    }
    const score =
      typeof scoreRaw === 'number' ? scoreRaw : Number(scoreRaw);
    // Redis ranks are 0-based; leaderboard rank is 1-based.
    const rank = (typeof rankRaw === 'number' ? rankRaw : Number(rankRaw)) + 1;
    return { score, rank };
  }

  async getTop(
    scope: LeaderboardScope,
    limit = 50,
  ): Promise<Array<{ userId: string; score: number }>> {
    const key = this.getKey(scope);
    if (limit <= 0) return [];
    const end = limit - 1;
    // redis v5 client exposes zRangeWithScores with an options object for reverse ordering.
    const entries = await this.redis.zRangeWithScores(key, 0, end, { REV: true });
    return entries.map((e) => ({
      userId: String(e.value),
      score: typeof e.score === 'number' ? e.score : Number(e.score),
    }));
  }
}

