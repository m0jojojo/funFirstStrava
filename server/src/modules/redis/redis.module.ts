import { Global, Module } from '@nestjs/common';
import { createClient, type RedisClientType } from 'redis';
import { REDIS_CLIENT } from './redis.constants';
import { RedisService } from './redis.service';

@Global()
@Module({
  providers: [
    {
      provide: REDIS_CLIENT,
      useFactory: async (): Promise<RedisClientType> => {
        const url = process.env.REDIS_URL ?? 'redis://127.0.0.1:6379';
        const client: RedisClientType = createClient({ url });
        client.on('error', (err) => {
          // eslint-disable-next-line no-console
          console.error('[Redis] Client error', err);
        });
        await client.connect();
        return client;
      },
    },
    RedisService,
  ],
  exports: [REDIS_CLIENT, RedisService],
})
export class RedisModule {}

