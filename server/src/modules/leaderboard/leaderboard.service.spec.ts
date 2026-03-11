import { Test, TestingModule } from '@nestjs/testing';
import { LeaderboardService, type LeaderboardScope } from './leaderboard.service';
import { REDIS_CLIENT } from '../redis/redis.constants';

describe('LeaderboardService', () => {
  let service: LeaderboardService;

  const mockRedis = {
    on: jest.fn(),
    zIncrBy: jest.fn(),
    zScore: jest.fn(),
    zRevRank: jest.fn(),
    zRangeWithScores: jest.fn(),
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
});



