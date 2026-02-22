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

  /** Phase 10.1: tiles near (lat, lng). Returns tiles whose bbox intersects the radius square. */
  async findNear(
    lat: number,
    lng: number,
    options?: { radiusKm?: number; limit?: number },
  ): Promise<Tile[]> {
    const radiusKm = Math.min(50, Math.max(0.1, options?.radiusKm ?? 2));
    const limit = Math.min(10000, Math.max(1, options?.limit ?? 500));
    const degPerKmLat = 1 / 111;
    const degPerKmLng = 1 / (111 * Math.cos((lat * Math.PI) / 180));
    const deltaLat = radiusKm * degPerKmLat;
    const deltaLng = radiusKm * degPerKmLng;
    const minLat = lat - deltaLat;
    const maxLat = lat + deltaLat;
    const minLng = lng - deltaLng;
    const maxLng = lng + deltaLng;
    return this.tilesRepository
      .createQueryBuilder('tile')
      .where('tile.min_lat <= :maxLat', { maxLat })
      .andWhere('tile.max_lat >= :minLat', { minLat })
      .andWhere('tile.min_lng <= :maxLng', { maxLng })
      .andWhere('tile.max_lng >= :minLng', { minLng })
      .orderBy('tile.row_index', 'ASC')
      .addOrderBy('tile.col_index', 'ASC')
      .limit(limit)
      .getMany();
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

    interface Region {
      minLat: number;
      maxLat: number;
      minLng: number;
      maxLng: number;
      rows: number;
      cols: number;
      rowOffset: number;
      colOffset: number;
    }

    const regions: Region[] = [
      {
        // Sector 40 Gurgaon: (28.450665,77.043455), (28.440776,77.055246), (28.449613,77.063986), (28.459290,77.050180)
        minLat: 28.440776,
        maxLat: 28.45929,
        minLng: 77.043455,
        maxLng: 77.063986,
        rows: 50,
        cols: 100,
        rowOffset: 0,
        colOffset: 0,
      },
      {
        // Rewari: (28.196031,76.739296), (28.120541,76.632614), (28.192237,76.610443), (28.225281,76.680314)
        minLat: 28.120541,
        maxLat: 28.225281,
        minLng: 76.610443,
        maxLng: 76.739296,
        rows: 80,
        cols: 80,
        rowOffset: 100,
        colOffset: 0,
      },
    ];

    const BATCH_SIZE = 1000;
    for (const r of regions) {
      const tileHeight = (r.maxLat - r.minLat) / r.rows;
      const tileWidth = (r.maxLng - r.minLng) / r.cols;
      const tiles: Tile[] = [];

      for (let row = 0; row < r.rows; row += 1) {
        for (let col = 0; col < r.cols; col += 1) {
          const tileMinLat = r.minLat + row * tileHeight;
          const tileMaxLat = tileMinLat + tileHeight;
          const tileMinLng = r.minLng + col * tileWidth;
          const tileMaxLng = tileMinLng + tileWidth;

          tiles.push(
            this.tilesRepository.create({
              rowIndex: r.rowOffset + row,
              colIndex: r.colOffset + col,
              minLat: tileMinLat,
              maxLat: tileMaxLat,
              minLng: tileMinLng,
              maxLng: tileMaxLng,
            }),
          );
        }
      }

      for (let i = 0; i < tiles.length; i += BATCH_SIZE) {
        const batch = tiles.slice(i, i + BATCH_SIZE);
        await this.tilesRepository.save(batch);
      }
    }
  }
}

