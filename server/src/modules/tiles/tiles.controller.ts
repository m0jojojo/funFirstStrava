import { Controller, Get, Query, Req } from '@nestjs/common';
import type { Request } from 'express';
import { Tile } from './tile.entity';
import { LeaderboardEntry, TilesService } from './tiles.service';
import { FirebaseTokenService } from '../users/firebase-token.service';
import { UsersService } from '../users/users.service';

interface TilesNearTile {
  id: string;
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
  ownerId: string | null;
}

@Controller('tiles')
export class TilesController {
  constructor(
    private readonly tilesService: TilesService,
    private readonly firebaseToken: FirebaseTokenService,
    private readonly usersService: UsersService,
  ) {}

  @Get()
  async findAll(): Promise<Tile[]> {
    return this.tilesService.findAll();
  }

  /** Returns { tiles, currentUserId } for map fallback when /tiles/near is unavailable. */
  @Get('all')
  async findAllWithUser(
    @Req() req?: Request,
  ): Promise<{ tiles: TilesNearTile[]; currentUserId: string | null }> {
    let currentUserId: string | null = null;
    const auth = req?.headers?.authorization;
    if (auth?.startsWith('Bearer ')) {
      try {
        const payload = await this.firebaseToken.verifyIdToken(auth.slice(7).trim());
        const user = await this.usersService.findByFirebaseUid(payload.sub);
        if (user) currentUserId = user.id;
      } catch {
        /* ignore */
      }
    }
    const tiles = await this.tilesService.findAll();
    const mapped: TilesNearTile[] = tiles.map((t) => ({
      id: t.id,
      minLat: t.minLat,
      maxLat: t.maxLat,
      minLng: t.minLng,
      maxLng: t.maxLng,
      ownerId: t.ownerId ?? null,
    }));
    return { tiles: mapped, currentUserId };
  }

  @Get('near')
  async findNear(
    @Query('lat') latStr?: string,
    @Query('lng') lngStr?: string,
    @Query('radiusKm') radiusKmStr?: string,
    @Query('limit') limitStr?: string,
    @Req() req?: Request,
  ): Promise<{ tiles: TilesNearTile[]; currentUserId: string | null }> {
    let currentUserId: string | null = null;
    const auth = req?.headers?.authorization;
    if (auth?.startsWith('Bearer ')) {
      try {
        const payload = await this.firebaseToken.verifyIdToken(auth.slice(7).trim());
        const user = await this.usersService.findByFirebaseUid(payload.sub);
        if (user) currentUserId = user.id;
      } catch {
        /* ignore */
      }
    }

    const lat = latStr != null ? parseFloat(latStr) : NaN;
    const lng = lngStr != null ? parseFloat(lngStr) : NaN;
    let tiles: Tile[];
    if (Number.isNaN(lat) || Number.isNaN(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      tiles = await this.tilesService.findAll();
    } else {
      const radiusKm = radiusKmStr != null ? parseFloat(radiusKmStr) : undefined;
      const limit = limitStr != null ? parseInt(limitStr, 10) : undefined;
      tiles = await this.tilesService.findNear(lat, lng, { radiusKm, limit });
    }
    const mapped: TilesNearTile[] = tiles.map((t) => ({
      id: t.id,
      minLat: t.minLat,
      maxLat: t.maxLat,
      minLng: t.minLng,
      maxLng: t.maxLng,
      ownerId: t.ownerId ?? null,
    }));
    return { tiles: mapped, currentUserId };
  }

  @Get('leaderboard')
  async getLeaderboard(
    @Query('limit') limit?: string,
  ): Promise<LeaderboardEntry[]> {
    const n = limit ? Math.min(100, Math.max(1, parseInt(limit, 10) || 20)) : 20;
    return this.tilesService.getLeaderboard(n);
  }
}

