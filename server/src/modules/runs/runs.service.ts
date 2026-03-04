import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PathPoint } from './run.entity';
import { Run } from './run.entity';
import { TilesService } from '../tiles/tiles.service';
import { User } from '../users/user.entity';

/** Soft max speed between consecutive points (m/s). Above this we treat the segment as suspicious. ~25 km/h. */
const SOFT_MAX_SPEED_MS = 7;
/** Hard max speed (m/s). Above this we reject the whole run as clearly impossible. ~90 km/h. */
const HARD_MAX_SPEED_MS = 25;
/** Minimum distance (m) required to hard-reject a high-speed segment.
 *  This avoids rejecting runs due to small GPS jitter when the user is standing still. */
const MIN_DIST_FOR_REJECT_M = 150;
/** Segments with time gap above this (ms) are not speed-checked. Handles background GPS throttling / long pauses. */
const GAP_SKIP_MS = 60_000; // 1 minute

@Injectable()
export class RunsService {
  constructor(
    @InjectRepository(Run)
    private readonly runRepo: Repository<Run>,
    private readonly tilesService: TilesService,
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
      if (speedMs > HARD_MAX_SPEED_MS && distM > MIN_DIST_FOR_REJECT_M) {
        // Clearly impossible / vehicle-speed jump: reject the whole run.
        this.logger.warn(
          `Rejecting run path (hard limit): segment index=${i - 1}->${i} dtMs=${dtMs} distM=${distM.toFixed(
            1,
          )} speedMs=${speedMs.toFixed(2)} (hardMax=${HARD_MAX_SPEED_MS})`,
        );
        throw new BadRequestException(
          `Path invalid: segment speed ${speedMs.toFixed(
            1,
          )} m/s exceeds hard max ${HARD_MAX_SPEED_MS} m/s`,
        );
      }
      if (speedMs > SOFT_MAX_SPEED_MS && distM > MIN_DIST_FOR_REJECT_M) {
        // Likely vehicle movement: log and skip this segment instead of rejecting entire run.
        this.logger.warn(
          `Skipping high-speed segment: index=${i - 1}->${i} dtMs=${dtMs} distM=${distM.toFixed(
            1,
          )} speedMs=${speedMs.toFixed(2)} (softMax=${SOFT_MAX_SPEED_MS})`,
        );
        continue;
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
    const tilesCaptured = await this.tilesService.captureTilesByPath(user.id, path);
    run.tilesCaptured = tilesCaptured;
    const saved = await this.runRepo.save(run);
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
