import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Run } from '../runs/run.entity';
import { Tile } from '../tiles/tile.entity';
import { User } from '../users/user.entity';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      useFactory: () => ({
        // TypeORM connection configuration.
        // Uses environment variables with sensible local defaults.
        // This keeps DB credentials out of source control.
        type: 'postgres' as const,
        host: process.env.DB_HOST ?? 'localhost',
        port: Number(process.env.DB_PORT ?? 5432),
        username: process.env.DB_USERNAME ?? 'postgres',
        password: process.env.DB_PASSWORD ?? 'postgres',
        database: process.env.DB_NAME ?? 'territory_game',
        entities: [User, Tile, Run],
        // NOTE: synchronize is enabled for early development convenience.
        // We will replace this with proper migrations in later phases.
        synchronize: true,
      }),
    }),
  ],
})
export class DatabaseModule {}

