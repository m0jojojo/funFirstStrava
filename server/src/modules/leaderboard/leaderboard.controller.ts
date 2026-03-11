import {
  Controller,
  Get,
  Param,
  Query,
} from '@nestjs/common';
import { LeaderboardService, type LeaderboardScope } from './leaderboard.service';

@Controller('leaderboards')
export class LeaderboardController {
  constructor(private readonly leaderboardService: LeaderboardService) {}

  @Get('global')
  async getGlobalTop(
    @Query('limit') limit?: string,
  ): Promise<Array<{ userId: string; score: number }>> {
    const n = this.parseLimit(limit);
    return this.leaderboardService.getTop({ type: 'global' }, n);
  }

  @Get('country/:countryCode')
  async getCountryTop(
    @Param('countryCode') countryCode: string,
    @Query('limit') limit?: string,
  ): Promise<Array<{ userId: string; score: number }>> {
    const n = this.parseLimit(limit);
    const scope: LeaderboardScope = { type: 'country', countryCode };
    return this.leaderboardService.getTop(scope, n);
  }

  @Get('city/:cityName')
  async getCityTop(
    @Param('cityName') cityName: string,
    @Query('limit') limit?: string,
  ): Promise<Array<{ userId: string; score: number }>> {
    const n = this.parseLimit(limit);
    const scope: LeaderboardScope = { type: 'city', cityName };
    return this.leaderboardService.getTop(scope, n);
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
}


