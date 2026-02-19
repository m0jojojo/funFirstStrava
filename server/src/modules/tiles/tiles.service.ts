import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Tile } from './tile.entity';
import { TilesGateway } from './tiles.gateway';
import { UsersService } from '../users/users.service';

export interface LeaderboardEntry {
  userId: string;
  username: string;
  tileCount: number;
}

@Injectable()
export class TilesService implements OnModuleInit {
  constructor(
    @InjectRepository(Tile)
    private readonly tilesRepository: Repository<Tile>,
    private readonly usersService: UsersService,
    private readonly tilesGateway: TilesGateway,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.seedIfEmpty();
  }

  async findAll(): Promise<Tile[]> {
    return this.tilesRepository.find({ order: { rowIndex: 'ASC', colIndex: 'ASC' } });
  }

  /** Phase 6.3: top users by tile count (owned tiles). */
  async getLeaderboard(limit = 20): Promise<LeaderboardEntry[]> {
    const rows = await this.tilesRepository
      .createQueryBuilder('tile')
      .select('tile.owner_id', 'userId')
      .addSelect('COUNT(*)', 'tileCount')
      .where('tile.owner_id IS NOT NULL')
      .groupBy('tile.owner_id')
      .orderBy('COUNT(*)', 'DESC')
      .limit(limit)
      .getRawMany<{ userId: string; tileCount: string }>();

    if (rows.length === 0) return [];
    const userIds = rows.map((r) => r.userId);
    const users = await this.usersService.findByIds(userIds);
    const userMap = new Map(users.map((u) => [u.id, u.username]));
    return rows.map((r) => ({
      userId: r.userId,
      username: userMap.get(r.userId) ?? 'Unknown',
      tileCount: parseInt(String(r.tileCount), 10),
    }));
  }

  /**
   * Find tile IDs that contain at least one path point (point-in-rect), then set their owner_id.
   * Phase 6.1: capture tiles when a run passes through them.
   */
  async captureTilesByPath(
    userId: string,
    path: Array<{ lat: number; lng: number }>,
  ): Promise<void> {
    if (path.length === 0) return;
    const allTiles = await this.tilesRepository.find();
    const tileIdsToCapture = new Set<string>();
    for (const point of path) {
      for (const tile of allTiles) {
        if (
          point.lat >= tile.minLat &&
          point.lat <= tile.maxLat &&
          point.lng >= tile.minLng &&
          point.lng <= tile.maxLng
        ) {
          tileIdsToCapture.add(tile.id);
        }
      }
    }
    if (tileIdsToCapture.size > 0) {
      await this.tilesRepository.update(
        { id: In([...tileIdsToCapture]) },
        { ownerId: userId },
      );
      this.tilesGateway.broadcastTilesUpdated(userId, tileIdsToCapture.size);
    }
  }

  private async seedIfEmpty(): Promise<void> {
    const count = await this.tilesRepository.count();
    if (count > 0) return;

    // Bounding box from user coordinates (4 corners). 50×100 = 5,000 tiles.
    // Points: (28.450665,77.043455), (28.440776,77.055246), (28.449613,77.063986), (28.459290,77.050180)
    const minLat = 28.440776;
    const maxLat = 28.45929;
    const minLng = 77.043455;
    const maxLng = 77.063986;
    const rows = 50;
    const cols = 100;
    const tileHeight = (maxLat - minLat) / rows;
    const tileWidth = (maxLng - minLng) / cols;

    const tiles: Tile[] = [];

    for (let row = 0; row < rows; row += 1) {
      for (let col = 0; col < cols; col += 1) {
        const tileMinLat = minLat + row * tileHeight;
        const tileMaxLat = tileMinLat + tileHeight;
        const tileMinLng = minLng + col * tileWidth;
        const tileMaxLng = tileMinLng + tileWidth;

        tiles.push(
          this.tilesRepository.create({
            rowIndex: row,
            colIndex: col,
            minLat: tileMinLat,
            maxLat: tileMaxLat,
            minLng: tileMinLng,
            maxLng: tileMaxLng,
          }),
        );
      }
    }

    // PostgreSQL limits parameters per query; save in batches to avoid "bind message has X parameter formats but 0 parameters"
    const BATCH_SIZE = 1000;
    for (let i = 0; i < tiles.length; i += BATCH_SIZE) {
      const batch = tiles.slice(i, i + BATCH_SIZE);
      await this.tilesRepository.save(batch);
    }
  }
}

