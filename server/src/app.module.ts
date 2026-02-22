import { Module } from '@nestjs/common';
import { HealthController } from './health/health.controller';
import { DatabaseModule } from './modules/database/database.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { RunsModule } from './modules/runs/runs.module';
import { TilesModule } from './modules/tiles/tiles.module';
import { UsersModule } from './modules/users/users.module';

@Module({
  imports: [DatabaseModule, NotificationsModule, UsersModule, TilesModule, RunsModule],
  controllers: [HealthController],
  providers: [],
})
export class AppModule {}
