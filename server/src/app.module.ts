import { Module } from '@nestjs/common';
import { HealthController } from './health/health.controller';
import { DatabaseModule } from './modules/database/database.module';

@Module({
  imports: [DatabaseModule],
  controllers: [HealthController],
  providers: [],
})
export class AppModule {}
