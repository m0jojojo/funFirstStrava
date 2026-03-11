import { WebSocketGateway } from '@nestjs/websockets';

@WebSocketGateway({ cors: { origin: true } })
export class LeaderboardGateway {}

