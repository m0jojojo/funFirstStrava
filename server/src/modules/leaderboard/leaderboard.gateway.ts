import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server } from 'socket.io';
import type { LeaderboardScope } from './leaderboard.service';

@WebSocketGateway({ cors: { origin: true } })
export class LeaderboardGateway {
  @WebSocketServer()
  server!: Server;

  broadcastRankChange(payload: {
    userId: string;
    scope: LeaderboardScope;
    newRank: number;
    score: number;
  }): void {
    if (!this.server) return;
    this.server.emit('leaderboard_update', {
      type: 'leaderboard_update',
      ...payload,
    });
  }
}

