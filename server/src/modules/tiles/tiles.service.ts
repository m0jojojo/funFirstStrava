import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Tile } from './tile.entity';
import { TilesGateway } from './tiles.gateway';
import { PushNotificationService } from '../notifications/push-notification.service';
import { UsersService } from '../users/users.service';

const ORIGIN_LAT = -90;
const ORIGIN_LNG = -180;
// ~20 m × 20 m (1° lat ≈ 111 km; same deg for lng gives ~20 m E–W at low latitudes)
const TILE_DEG_LAT = 20 / 111_000;
const TILE_DEG_LNG = 20 / 111_000;

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
    private readonly pushService: PushNotificationService,
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

    const minRow = Math.floor((minLat - ORIGIN_LAT) / TILE_DEG_LAT);
    const maxRow = Math.floor((maxLat - ORIGIN_LAT) / TILE_DEG_LAT);
    const minCol = Math.floor((minLng - ORIGIN_LNG) / TILE_DEG_LNG);
    const maxCol = Math.floor((maxLng - ORIGIN_LNG) / TILE_DEG_LNG);

    return this.tilesRepository
      .createQueryBuilder('tile')
      .where('tile.row_index BETWEEN :minRow AND :maxRow', { minRow, maxRow })
      .andWhere('tile.col_index BETWEEN :minCol AND :maxCol', { minCol, maxCol })
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
   * Notifies previous owners (whose tiles were captured) via push notification.
   */
  async captureTilesByPath(
    userId: string,
    path: Array<{ lat: number; lng: number }>,
  ): Promise<void> {
    if (path.length === 0) return;
    const visitedKeys = new Set<string>();
    const tilesToSave: Tile[] = [];
    const previousOwnerByTile = new Map<string, string>();

    for (const point of path) {
      if (typeof point.lat !== 'number' || typeof point.lng !== 'number') continue;
      const { rowIndex, colIndex } = this.pointToIndices(point.lat, point.lng);
      const key = `${rowIndex}:${colIndex}`;
      if (visitedKeys.has(key)) continue;
      visitedKeys.add(key);

      let tile = await this.tilesRepository.findOne({
        where: { rowIndex, colIndex },
      });

      if (!tile) {
        const bounds = this.indicesToBounds(rowIndex, colIndex);
        tile = this.tilesRepository.create({
          rowIndex,
          colIndex,
          ...bounds,
        });
      }

      if (tile.ownerId && tile.ownerId !== userId) {
        previousOwnerByTile.set(tile.id, tile.ownerId);
      }

      tile.ownerId = userId;
      tilesToSave.push(tile);
    }

    if (tilesToSave.length === 0) return;

    const saved = await this.tilesRepository.save(tilesToSave);
    const uniqueIds = new Set(saved.map((t) => t.id));

    this.tilesGateway.broadcastTilesUpdated(userId, uniqueIds.size);

    const previousOwnerIds = [...new Set(previousOwnerByTile.values())];
    if (previousOwnerIds.length > 0) {
      await this.notifyPreviousOwners(previousOwnerIds, userId);
    }
  }

  private async notifyPreviousOwners(previousOwnerIds: string[], attackerId: string): Promise<void> {
    const users = await this.usersService.findByIds(previousOwnerIds);
    const attacker = await this.usersService.findByIds([attackerId]).then((u) => u[0]);
    const attackerName = attacker?.username ?? 'Someone';
    const tokens = users.filter((u) => u.fcmToken?.trim()).map((u) => u.fcmToken as string);
    if (tokens.length > 0) {
      await this.pushService.sendToTokens(
        tokens,
        'Territory captured!',
        `${attackerName} captured your tiles during their run.`,
        { type: 'tile_captured', attackerId },
      );
    }
  }

  private async seedIfEmpty(): Promise<void> {
    // Global grid is now generated lazily from GPS paths; no upfront seeding required.
    const count = await this.tilesRepository.count();
    if (count > 0) return;
  }

  private pointToIndices(lat: number, lng: number): { rowIndex: number; colIndex: number } {
    const rowIndex = Math.floor((lat - ORIGIN_LAT) / TILE_DEG_LAT);
    const colIndex = Math.floor((lng - ORIGIN_LNG) / TILE_DEG_LNG);
    return { rowIndex, colIndex };
  }

  private indicesToBounds(rowIndex: number, colIndex: number): {
    minLat: number;
    maxLat: number;
    minLng: number;
    maxLng: number;
  } {
    const minLat = ORIGIN_LAT + rowIndex * TILE_DEG_LAT;
    const maxLat = minLat + TILE_DEG_LAT;
    const minLng = ORIGIN_LNG + colIndex * TILE_DEG_LNG;
    const maxLng = minLng + TILE_DEG_LNG;
    return { minLat, maxLat, minLng, maxLng };
  }
}

