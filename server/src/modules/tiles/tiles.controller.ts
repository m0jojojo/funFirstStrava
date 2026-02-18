import { Controller, Get } from '@nestjs/common';
import { Tile } from './tile.entity';
import { TilesService } from './tiles.service';

@Controller('tiles')
export class TilesController {
  constructor(private readonly tilesService: TilesService) {}

  @Get()
  async findAll(): Promise<Tile[]> {
    return this.tilesService.findAll();
  }
}

