import { Test, TestingModule } from '@nestjs/testing';
import { LeaderboardService, type LeaderboardScope } from './leaderboard.service';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { LeaderboardGateway } from './leaderboard.gateway';

describe('LeaderboardService', () => {
  let service: LeaderboardService;

  const mockRedis = {
    on: jest.fn(),
    zIncrBy: jest.fn(),
    zScore: jest.fn(),
    zRevRank: jest.fn(),
    zRangeWithScores: jest.fn(),
  };

  const mockGateway = {
    broadcastRankChange: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LeaderboardService,
        {
          provide: REDIS_CLIENT,
          useValue: mockRedis,
        },
        {
          provide: LeaderboardGateway,
          useValue: mockGateway,
        },
      ],
    }).compile();

    service = module.get<LeaderboardService>(LeaderboardService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('incrementScore should call zIncrBy with global key', async () => {
    const scope: LeaderboardScope = { type: 'global' };
    mockRedis.zIncrBy.mockResolvedValueOnce(42);

    const result = await service.incrementScore('user-1', 10, scope);

    expect(mockRedis.zIncrBy).toHaveBeenCalledWith(
      'leaderboard:global',
      10,
      'user-1',
    );
    expect(result).toBe(42);
  });

  it('getScoreAndRank should map Redis rank to 1-based and parse score', async () => {
    const scope: LeaderboardScope = { type: 'country', countryCode: 'in' };
    mockRedis.zScore.mockResolvedValueOnce('100');
    mockRedis.zRevRank.mockResolvedValueOnce(0);

    const result = await service.getScoreAndRank('user-2', scope);

    expect(mockRedis.zScore).toHaveBeenCalledWith(
      'leaderboard:country:IN',
      'user-2',
    );
    expect(mockRedis.zRevRank).toHaveBeenCalledWith(
      'leaderboard:country:IN',
      'user-2',
    );
    expect(result).toEqual({ score: 100, rank: 1 });
  });

  it('getTop should adapt zRevRangeWithScores for city scope', async () => {
    const scope: LeaderboardScope = { type: 'city', cityName: 'Bangalore Central' };
    mockRedis.zRangeWithScores.mockResolvedValueOnce([
      { value: 'u1', score: 200 },
      { value: 'u2', score: '150' },
    ]);

    const result = await service.getTop(scope, 2);

    expect(mockRedis.zRangeWithScores).toHaveBeenCalledWith(
      'leaderboard:city:bangalore_central',
      0,
      1,
      { REV: true },
    );
    expect(result).toEqual([
      { userId: 'u1', score: 200 },
      { userId: 'u2', score: 150 },
    ]);
  });

  it('updateScore should call increment for each provided scope', async () => {
    const scopeGlobal: LeaderboardScope = { type: 'global' };
    const scopeCountry: LeaderboardScope = { type: 'country', countryCode: 'us' };
    mockRedis.zIncrBy.mockResolvedValue(10);

    await service.updateScore('user-3', 5, [scopeGlobal, scopeCountry]);

    expect(mockRedis.zIncrBy).toHaveBeenCalledWith(
      'leaderboard:global',
      5,
      'user-3',
    );
    expect(mockRedis.zIncrBy).toHaveBeenCalledWith(
      'leaderboard:country:US',
      5,
      'user-3',
    );
  });

  it('getTop should use in-memory cache within TTL', async () => {
    const scope: LeaderboardScope = { type: 'global' };
    mockRedis.zRangeWithScores.mockResolvedValueOnce([
      { value: 'u1', score: 5 },
    ]);

    const first = await service.getTop(scope, 5);
    const second = await service.getTop(scope, 5);

    // Redis should have been called only once; second call hits cache.
    expect(mockRedis.zRangeWithScores).toHaveBeenCalledTimes(1);
    expect(first).toEqual([{ userId: 'u1', score: 5 }]);
    expect(second).toEqual(first);
  });

  it('updateScoreAndDetectRank should report rank change when moving up', async () => {
    const scope: LeaderboardScope = { type: 'global' };

    // Before: score 10, rank 3
    mockRedis.zScore
      .mockResolvedValueOnce('10') // first getScoreAndRank
      .mockResolvedValueOnce('30'); // second getScoreAndRank
    mockRedis.zRevRank
      .mockResolvedValueOnce(2) // old rank (3)
      .mockResolvedValueOnce(0); // new rank (1)
    mockRedis.zIncrBy.mockResolvedValueOnce(30);

    const result = await service.updateScoreAndDetectRank('user-4', 20, scope);

    expect(mockRedis.zScore).toHaveBeenCalledTimes(2);
    expect(mockRedis.zRevRank).toHaveBeenCalledTimes(2);
    expect(mockRedis.zIncrBy).toHaveBeenCalledWith(
      'leaderboard:global',
      20,
      'user-4',
    );
    expect(result.changed).toBe(true);
    expect(result.oldRank).toBe(3);
    expect(result.newRank).toBe(1);
    expect(result.oldScore).toBe(10);
    expect(result.newScore).toBe(30);
  });

  it('updateScoreAndNotify should emit event whenever score updates (subject to throttle)', async () => {
    const scope: LeaderboardScope = { type: 'global' };

    // Mock underlying rank detection to signal change.
    const spy = jest
      .spyOn(service, 'updateScoreAndDetectRank')
      .mockResolvedValueOnce({
        scope,
        userId: 'user-5',
        oldScore: 5,
        oldRank: 4,
        newScore: 15,
        newRank: 2,
        changed: true,
      });

    const nowSpy = jest.spyOn(Date, 'now');
    nowSpy.mockReturnValueOnce(0);

    await service.updateScoreAndNotify('user-5', 10, scope);

    expect(spy).toHaveBeenCalledWith('user-5', 10, scope);
    expect(mockGateway.broadcastRankChange).toHaveBeenCalledWith({
      userId: 'user-5',
      scope,
      newRank: 2,
      score: 15,
    });

    // Now simulate no rank change but score increase: still emit.
    mockGateway.broadcastRankChange.mockClear();
    spy.mockResolvedValueOnce({
      scope,
      userId: 'user-5',
      oldScore: 15,
      oldRank: 2,
      newScore: 20,
      newRank: 2,
      changed: false,
    });

    nowSpy.mockReturnValueOnce(11_000);

    await service.updateScoreAndNotify('user-5', 5, scope);

    expect(mockGateway.broadcastRankChange).toHaveBeenCalledWith({
      userId: 'user-5',
      scope,
      newRank: 2,
      score: 20,
    });
    nowSpy.mockRestore();
  });

  it('updateScoreAndNotify should throttle repeated calls within window', async () => {
    const scope: LeaderboardScope = { type: 'global' };
    const spy = jest
      .spyOn(service, 'updateScoreAndDetectRank')
      .mockResolvedValue({
        scope,
        userId: 'user-throttle',
        oldScore: 0,
        oldRank: null,
        newScore: 10,
        newRank: 1,
        changed: true,
      });
    const nowSpy = jest.spyOn(Date, 'now');

    // All calls at t=0ms → only the first should go through, the rest throttled.
    nowSpy.mockReturnValue(0);

    await service.updateScoreAndNotify('user-throttle', 10, scope);
    await service.updateScoreAndNotify('user-throttle', 10, scope);
    await service.updateScoreAndNotify('user-throttle', 10, scope);

    expect(spy).toHaveBeenCalledTimes(1);

    nowSpy.mockRestore();
  });
});



