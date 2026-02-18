import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Tile } from './tile.entity';

@Injectable()
export class TilesService implements OnModuleInit {
  constructor(
    @InjectRepository(Tile)
    private readonly tilesRepository: Repository<Tile>,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.seedIfEmpty();
  }

  async findAll(): Promise<Tile[]> {
    return this.tilesRepository.find();
  }

  private async seedIfEmpty(): Promise<void> {
    const count = await this.tilesRepository.count();
    if (count > 0) return;

    // Simple demo grid: 10x10 tiles around a fixed area.
    // These values are arbitrary and can be adjusted later.
    const originLat = 37.7749; // example latitude
    const originLng = -122.4194; // example longitude
    const tileSize = 0.002; // degrees (~200m, depends on latitude)
    const rows = 10;
    const cols = 10;

    const tiles: Tile[] = [];

    for (let row = 0; row < rows; row += 1) {
      for (let col = 0; col < cols; col += 1) {
        const minLat = originLat + row * tileSize;
        const maxLat = originLat + (row + 1) * tileSize;
        const minLng = originLng + col * tileSize;
        const maxLng = originLng + (col + 1) * tileSize;

        tiles.push(
          this.tilesRepository.create({
            rowIndex: row,
            colIndex: col,
            minLat,
            minLng,
            maxLat,
            maxLng,
          }),
        );
      }
    }

    await this.tilesRepository.save(tiles);
  }
}

