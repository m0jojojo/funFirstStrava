import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Run } from '../runs/run.entity';
import { Tile } from '../tiles/tile.entity';
import { User } from '../users/user.entity';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      useFactory: () => {
        // Railway (and many hosts) provide a single DATABASE_URL; use it when set.
        const databaseUrl = process.env.DATABASE_URL;
        const base = {
          type: 'postgres' as const,
          entities: [User, Tile, Run],
          synchronize: true,
        };
        if (databaseUrl) {
          // Railway and most cloud Postgres require SSL; rejectUnauthorized: false for shared certs.
          return {
            ...base,
            url: databaseUrl,
            ssl: { rejectUnauthorized: false },
          };
        }
        return {
          ...base,
          host: process.env.DB_HOST ?? 'localhost',
          port: Number(process.env.DB_PORT ?? 5432),
          username: process.env.DB_USERNAME ?? 'postgres',
          password: process.env.DB_PASSWORD ?? 'postgres',
          database: process.env.DB_NAME ?? 'territory_game',
        };
      },
    }),
  ],
})
export class DatabaseModule {}

