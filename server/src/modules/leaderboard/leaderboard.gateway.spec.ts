import { LeaderboardGateway } from './leaderboard.gateway';
import type { LeaderboardScope } from './leaderboard.service';

describe('LeaderboardGateway', () => {
  it('broadcastRankChange should emit leaderboard_update event', () => {
    const gateway = new LeaderboardGateway();
    const emit = jest.fn();
    // @ts-expect-error manual injection for test
    gateway.server = { emit } as any;

    const scope: LeaderboardScope = { type: 'global' };
    gateway.broadcastRankChange({
      userId: 'user-1',
      scope,
      newRank: 2,
      score: 50,
    });

    expect(emit).toHaveBeenCalledWith('leaderboard_update', {
      type: 'leaderboard_update',
      userId: 'user-1',
      scope,
      newRank: 2,
      score: 50,
    });
  });
});

