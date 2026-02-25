import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PathPoint } from './run.entity';
import { Run } from './run.entity';
import { TilesService } from '../tiles/tiles.service';
import { User } from '../users/user.entity';

/** Max allowed speed between consecutive path points (m/s). ~54 km/h; rejects driving/teleport. */
const MAX_SPEED_MS = 15;

@Injectable()
export class RunsService {
  constructor(
    @InjectRepository(Run)
    private readonly runRepo: Repository<Run>,
    private readonly tilesService: TilesService,
  ) {}

  /** Phase 6.4 anti-cheat: reject path if any segment exceeds max speed. */
  private validatePath(path: PathPoint[]): void {
    for (let i = 1; i < path.length; i++) {
      const a = path[i - 1];
      const b = path[i];
      const dtMs = Math.abs((b.t ?? 0) - (a.t ?? 0));
      if (dtMs <= 0) continue;
      const distM = haversineM(a.lat, a.lng, b.lat, b.lng);
      const speedMs = distM / (dtMs / 1000);
      if (speedMs > MAX_SPEED_MS) {
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
    const saved = await this.runRepo.save(run);
    await this.tilesService.captureTilesByPath(user.id, path);
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
