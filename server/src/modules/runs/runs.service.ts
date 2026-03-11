import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PathPoint } from './run.entity';
import { Run } from './run.entity';
import { TilesService } from '../tiles/tiles.service';
import { User } from '../users/user.entity';
import { LeaderboardService } from '../leaderboard/leaderboard.service';

/** Max allowed speed between consecutive path points (m/s). ~54 km/h; rejects driving/teleport. */
const MAX_SPEED_MS = 15;
/** Segments with time gap above this (ms) are not speed-checked. Handles background GPS throttling / long pauses. */
const GAP_SKIP_MS = 60_000; // 1 minute

@Injectable()
export class RunsService {
  constructor(
    @InjectRepository(Run)
    private readonly runRepo: Repository<Run>,
    private readonly tilesService: TilesService,
    private readonly leaderboardService: LeaderboardService,
  ) {}

  private readonly logger = new Logger(RunsService.name);

  /** Phase 6.4 anti-cheat: reject path if any segment exceeds max speed. Skips segments with large time gaps (background GPS). */
  private validatePath(path: PathPoint[]): void {
    for (let i = 1; i < path.length; i++) {
      const a = path[i - 1];
      const b = path[i];
      const dtMs = Math.abs((b.t ?? 0) - (a.t ?? 0));
      if (dtMs <= 0) continue;
      if (dtMs > GAP_SKIP_MS) continue; // long gap = pause or background GPS; don't treat as teleport
      const distM = haversineM(a.lat, a.lng, b.lat, b.lng);
      const speedMs = distM / (dtMs / 1000);
      if (speedMs > MAX_SPEED_MS) {
        // Log enough context so we can debug 400s in Railway logs.
        this.logger.warn(
          `Rejecting run path: segment index=${i - 1}->${i} dtMs=${dtMs} distM=${distM.toFixed(
            1,
          )} speedMs=${speedMs.toFixed(2)} (max=${MAX_SPEED_MS})`,
        );
        throw new BadRequestException(
          `Path invalid: segment speed ${speedMs.toFixed(1)} m/s exceeds max ${MAX_SPEED_MS} m/s`,
        );
      }
    }
  }

  async create(user: User, path: PathPoint[]): Promise<Run> {
    if (!path.length) {
      throw new Error('Path cannot be empty');
    }
    this.validatePath(path);
    const startedAt = new Date(path[0].t);
    const endedAt = new Date(path[path.length - 1].t);
    const run = this.runRepo.create({
      userId: user.id,
      startedAt,
      endedAt,
      path,
    });
    const { captured: tilesCaptured, lostByUser } =
      await this.tilesService.captureTilesByPath(user.id, path);
    run.tilesCaptured = tilesCaptured;
    const saved = await this.runRepo.save(run);

    // Phase 7: update leaderboard and notify if rank changed (global scope for now).
    await this.leaderboardService.updateScoreAndNotify(user.id, tilesCaptured, {
      type: 'global',
    });

    // For any previous owners who lost tiles in this run, decrement their
    // leaderboard score so the total reflects current territory, not just
    // lifetime gains.
    const lostEntries = Object.entries(lostByUser ?? {});
    if (lostEntries.length > 0) {
      await Promise.all(
        lostEntries.map(([loserId, lostCount]) =>
          this.leaderboardService.updateScore(
            loserId,
            -Math.abs(Number(lostCount) || 0),
            { type: 'global' },
          ),
        ),
      );
    }

    return saved;
  }

  async findByUser(userId: string): Promise<Run[]> {
    return this.runRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  /** Total path distance in meters (Haversine sum over consecutive points). */
  computePathDistanceM(path: PathPoint[]): number {
    if (path.length < 2) return 0;
    let total = 0;
    for (let i = 1; i < path.length; i++) {
      total += haversineM(
        path[i - 1].lat,
        path[i - 1].lng,
        path[i].lat,
        path[i].lng,
      );
    }
    return total;
  }

  /**
   * One-time helper to backfill the global leaderboard from existing runs.
   *
   * It sums `tilesCaptured` per user across all historical runs and
   * increments the global leaderboard score for each user by that amount.
   *
   * NOTE: If you already have users on the leaderboard from recent runs,
   * this will add to their existing scores (i.e. may double-count those
   * recent runs). Intended for a single use right after introducing Redis.
   */
  async backfillGlobalLeaderboardFromRuns(): Promise<{
    usersUpdated: number;
    totalTiles: number;
  }> {
    const allRuns = await this.runRepo.find({
      where: {},
    });

    const totals = new Map<string, number>();
    for (const run of allRuns) {
      if (!run.tilesCaptured || run.tilesCaptured <= 0) continue;
      const prev = totals.get(run.userId) ?? 0;
      totals.set(run.userId, prev + run.tilesCaptured);
    }

    let usersUpdated = 0;
    let totalTiles = 0;

    for (const [userId, amount] of totals) {
      if (!userId || amount <= 0) continue;
      await this.leaderboardService.updateScore(userId, amount, {
        type: 'global',
      });
      usersUpdated += 1;
      totalTiles += amount;
    }

    this.logger.log(
      `Backfilled global leaderboard from runs: users=${usersUpdated} totalTiles=${totalTiles}`,
    );

    return { usersUpdated, totalTiles };
  }
}

/** Distance between two points in meters (Haversine). */
function haversineM(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const R = 6_371_000; // Earth radius in meters
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg: number): number {
  return (deg * Math.PI) / 180;
}
