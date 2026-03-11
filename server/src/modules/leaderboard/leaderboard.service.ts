import { Inject, Injectable, Logger } from '@nestjs/common';
import type { RedisClientType } from 'redis';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { LeaderboardGateway } from './leaderboard.gateway';

export type LeaderboardScope =
  | { type: 'global' }
  | { type: 'country'; countryCode: string }
  | { type: 'city'; cityName: string };

@Injectable()
export class LeaderboardService {
  private readonly logger = new Logger(LeaderboardService.name);

  constructor(
    @Inject(REDIS_CLIENT) private readonly redis: RedisClientType,
    private readonly gateway: LeaderboardGateway,
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

  /**
   * Generic entry point for other modules (runs/tiles) to apply a score delta
   * across one or more scopes. Later phases will add rank-change detection
   * and throttling on top of this method.
   */
  async updateScore(
    userId: string,
    amount: number,
    scopes: LeaderboardScope | LeaderboardScope[],
  ): Promise<void> {
    const scoped = Array.isArray(scopes) ? scopes : [scopes];
    const safeAmount = Number(amount) || 0;
    if (!userId || safeAmount === 0 || scoped.length === 0) return;
    await Promise.all(
      scoped.map((s) => this.incrementScore(userId, safeAmount, s)),
    );
  }

  async updateScoreAndDetectRank(
    userId: string,
    amount: number,
    scope: LeaderboardScope,
  ): Promise<{
    scope: LeaderboardScope;
    userId: string;
    oldScore: number | null;
    oldRank: number | null;
    newScore: number;
    newRank: number;
    changed: boolean;
  }> {
    const before = await this.getScoreAndRank(userId, scope);
    const newScore = await this.incrementScore(userId, amount, scope);
    const after = await this.getScoreAndRank(userId, scope);
    const oldScore = before.score;
    const oldRank = before.rank;
    const newRank = after.rank ?? null;
    const changed =
      oldRank === null || newRank === null ? true : newRank !== oldRank;
    return {
      scope,
      userId,
      oldScore,
      oldRank,
      newScore,
      newRank: newRank ?? 0,
      changed,
    };
  }

  async updateScoreAndNotify(
    userId: string,
    amount: number,
    scope: LeaderboardScope,
  ): Promise<void> {
    const result = await this.updateScoreAndDetectRank(userId, amount, scope);
    if (!result.changed) return;
    this.gateway.broadcastRankChange({
      userId,
      scope,
      newRank: result.newRank,
      score: result.newScore,
    });
  }
}

