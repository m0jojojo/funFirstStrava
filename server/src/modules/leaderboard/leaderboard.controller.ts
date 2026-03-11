import { Controller, Get, Param, Query } from '@nestjs/common';
import {
  LeaderboardService,
  type LeaderboardScope,
} from './leaderboard.service';
import { UsersService } from '../users/users.service';

@Controller('leaderboards')
export class LeaderboardController {
  constructor(
    private readonly leaderboardService: LeaderboardService,
    private readonly usersService: UsersService,
  ) {}

  @Get('global')
  async getGlobalTop(
    @Query('limit') limit?: string,
  ): Promise<
    Array<{ rank: number; userId: string; username: string | null; score: number }>
  > {
    const n = this.parseLimit(limit);
    const entries = await this.leaderboardService.getTop({ type: 'global' }, n);
    return this.attachUsernames(entries);
  }

  @Get('country/:countryCode')
  async getCountryTop(
    @Param('countryCode') countryCode: string,
    @Query('limit') limit?: string,
  ): Promise<
    Array<{ rank: number; userId: string; username: string | null; score: number }>
  > {
    const n = this.parseLimit(limit);
    const scope: LeaderboardScope = { type: 'country', countryCode };
    const entries = await this.leaderboardService.getTop(scope, n);
    return this.attachUsernames(entries);
  }

  @Get('city/:cityName')
  async getCityTop(
    @Param('cityName') cityName: string,
    @Query('limit') limit?: string,
  ): Promise<
    Array<{ rank: number; userId: string; username: string | null; score: number }>
  > {
    const n = this.parseLimit(limit);
    const scope: LeaderboardScope = { type: 'city', cityName };
    const entries = await this.leaderboardService.getTop(scope, n);
    return this.attachUsernames(entries);
  }

  @Get('user/:userId/global')
  async getUserGlobal(
    @Param('userId') userId: string,
  ): Promise<{ userId: string; score: number | null; rank: number | null }> {
    const result = await this.leaderboardService.getScoreAndRank(
      userId,
      { type: 'global' },
    );
    return { userId, ...result };
  }

  @Get('user/:userId/country/:countryCode')
  async getUserCountry(
    @Param('userId') userId: string,
    @Param('countryCode') countryCode: string,
  ): Promise<{ userId: string; score: number | null; rank: number | null }> {
    const scope: LeaderboardScope = { type: 'country', countryCode };
    const result = await this.leaderboardService.getScoreAndRank(userId, scope);
    return { userId, ...result };
  }

  @Get('user/:userId/city/:cityName')
  async getUserCity(
    @Param('userId') userId: string,
    @Param('cityName') cityName: string,
  ): Promise<{ userId: string; score: number | null; rank: number | null }> {
    const scope: LeaderboardScope = { type: 'city', cityName };
    const result = await this.leaderboardService.getScoreAndRank(userId, scope);
    return { userId, ...result };
  }

  private parseLimit(raw?: string): number {
    if (!raw) return 50;
    const n = Number(raw);
    if (!Number.isFinite(n) || n <= 0) return 50;
    return Math.min(100, Math.floor(n));
  }

  private async attachUsernames(
    items: Array<{ userId: string; score: number }>,
  ): Promise<
    Array<{ rank: number; userId: string; username: string | null; score: number }>
  > {
    if (items.length === 0) return [];
    const ids = Array.from(new Set(items.map((i) => i.userId).filter(Boolean)));
    const users = await this.usersService.findByIds(ids);
    const byId = new Map(users.map((u) => [u.id, u.username]));

    return items.map((item, index) => ({
      rank: index + 1,
      userId: item.userId,
      username: byId.get(item.userId) ?? null,
      score: item.score,
    }));
  }
}


