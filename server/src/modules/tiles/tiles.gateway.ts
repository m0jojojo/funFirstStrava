import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server } from 'socket.io';

/** Phase 6.4: broadcast tile capture events so clients can refresh without polling. */
@WebSocketGateway({ cors: { origin: true } })
export class TilesGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  handleConnection(): void {
    // Optional: log or track client count
  }

  handleDisconnect(): void {}

  /** Call after tiles are captured; all connected clients receive tiles_updated. */
  broadcastTilesUpdated(userId: string, tileCount: number): void {
    if (!this.server) return;
    this.server.emit('tiles_updated', { userId, tileCount });
  }
}
