import { Module } from '@nestjs/common';
import { LeaderboardService } from './leaderboard.service';
import { LeaderboardController } from './leaderboard.controller';
import { LeaderboardGateway } from './leaderboard.gateway';
import { RedisModule } from '../redis/redis.module';
import { UsersModule } from '../users/users.module';
import { TilesModule } from '../tiles/tiles.module';

@Module({
  imports: [RedisModule, UsersModule, TilesModule],
  controllers: [LeaderboardController],
  providers: [LeaderboardService, LeaderboardGateway],
  exports: [LeaderboardService],
})
export class LeaderboardModule {}

