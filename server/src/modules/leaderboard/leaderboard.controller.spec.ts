import { Test, TestingModule } from '@nestjs/testing';
import { LeaderboardController } from './leaderboard.controller';
import { LeaderboardService, type LeaderboardScope } from './leaderboard.service';

describe('LeaderboardController', () => {
  let controller: LeaderboardController;
  const mockService = {
    getTop: jest.fn(),
    getScoreAndRank: jest.fn(),
  } as unknown as jest.Mocked<LeaderboardService>;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      controllers: [LeaderboardController],
      providers: [
        {
          provide: LeaderboardService,
          useValue: mockService,
        },
      ],
    }).compile();

    controller = module.get<LeaderboardController>(LeaderboardController);
  });

  it('getGlobalTop should call service.getTop with global scope and parsed limit', async () => {
    mockService.getTop = jest.fn().mockResolvedValue([{ userId: 'u1', score: 10 }]);

    const result = await controller.getGlobalTop('5');

    expect(mockService.getTop).toHaveBeenCalledWith(
      { type: 'global' } as LeaderboardScope,
      5,
    );
    expect(result).toEqual([{ userId: 'u1', score: 10 }]);
  });

  it('getUserGlobal should call service.getScoreAndRank and wrap response', async () => {
    mockService.getScoreAndRank = jest.fn().mockResolvedValue({
      score: 42,
      rank: 3,
    });

    const result = await controller.getUserGlobal('user-abc');

    expect(mockService.getScoreAndRank).toHaveBeenCalledWith(
      'user-abc',
      { type: 'global' } as LeaderboardScope,
    );
    expect(result).toEqual({
      userId: 'user-abc',
      score: 42,
      rank: 3,
    });
  });
});

