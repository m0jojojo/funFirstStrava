import { Injectable, Logger } from '@nestjs/common';

@Injectable()
export class LeaderboardService {
  private readonly logger = new Logger(LeaderboardService.name);
}

