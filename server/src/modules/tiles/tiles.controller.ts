import { Controller, Get, Query } from '@nestjs/common';
import { Tile } from './tile.entity';
import { LeaderboardEntry, TilesService } from './tiles.service';

@Controller('tiles')
export class TilesController {
  constructor(private readonly tilesService: TilesService) {}

  @Get()
  async findAll(): Promise<Tile[]> {
    return this.tilesService.findAll();
  }

  @Get('leaderboard')
  async getLeaderboard(
    @Query('limit') limit?: string,
  ): Promise<LeaderboardEntry[]> {
    const n = limit ? Math.min(100, Math.max(1, parseInt(limit, 10) || 20)) : 20;
    return this.tilesService.getLeaderboard(n);
  }
}

