import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Tile } from './tile.entity';
import { TilesController } from './tiles.controller';
import { TilesGateway } from './tiles.gateway';
import { TilesService } from './tiles.service';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [TypeOrmModule.forFeature([Tile]), UsersModule],
  controllers: [TilesController],
  providers: [TilesGateway, TilesService],
  exports: [TilesService],
})
export class TilesModule {}

