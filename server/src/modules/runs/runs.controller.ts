import { Body, Controller, Get, HttpCode, HttpStatus, Logger, Post, UseGuards } from '@nestjs/common';
import { CreateRunDto } from './dto/create-run.dto';
import { RunsService } from './runs.service';
import { FirebaseAuthGuard } from '../users/firebase-auth.guard';
import { CurrentUser } from '../users/user.decorator';
import { User } from '../users/user.entity';

@Controller('runs')
@UseGuards(FirebaseAuthGuard)
export class RunsController {
  private readonly logger = new Logger(RunsController.name);

  constructor(private readonly runsService: RunsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@CurrentUser() user: User, @Body() dto: CreateRunDto) {
    const run = await this.runsService.create(user, dto.path);
    this.logger.log(`Run created id=${run.id} userId=${user.id} points=${run.path.length}`);
    return {
      id: run.id,
      startedAt: run.startedAt,
      endedAt: run.endedAt,
      pathLength: run.path.length,
    };
  }

  @Get('me')
  async findMine(@CurrentUser() user: User) {
    const runs = await this.runsService.findByUser(user.id);
    return runs.map((r) => ({
      id: r.id,
      startedAt: r.startedAt,
      endedAt: r.endedAt,
      pathLength: r.path.length,
      distanceMeters: this.runsService.computePathDistanceM(r.path),
    }));
  }
}
