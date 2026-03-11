import { Test, TestingModule } from '@nestjs/testing';
import { LeaderboardController } from './leaderboard.controller';
import { LeaderboardService, type LeaderboardScope } from './leaderboard.service';
import { UsersService } from '../users/users.service';

describe('LeaderboardController', () => {
  let controller: LeaderboardController;
  const mockLeaderboardService = {
    getTop: jest.fn(),
    getScoreAndRank: jest.fn(),
  } as unknown as jest.Mocked<LeaderboardService>;
  const mockUsersService = {
    findByIds: jest.fn(),
  } as unknown as jest.Mocked<UsersService>;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      controllers: [LeaderboardController],
      providers: [
        {
          provide: LeaderboardService,
          useValue: mockLeaderboardService,
        },
        {
          provide: UsersService,
          useValue: mockUsersService,
        },
      ],
    }).compile();

    controller = module.get<LeaderboardController>(LeaderboardController);
  });

  it('getGlobalTop should call service.getTop with global scope and parsed limit', async () => {
    mockLeaderboardService.getTop = jest
      .fn()
      .mockResolvedValue([{ userId: 'u1', score: 10 }]);
    mockUsersService.findByIds = jest.fn().mockResolvedValue([
      { id: 'u1', username: 'Alex' } as any,
    ]);

    const result = await controller.getGlobalTop('5');

    expect(mockLeaderboardService.getTop).toHaveBeenCalledWith(
      { type: 'global' } as LeaderboardScope,
      5,
    );
    expect(mockUsersService.findByIds).toHaveBeenCalledWith(['u1']);
    expect(result).toEqual([
      { rank: 1, userId: 'u1', username: 'Alex', score: 10 },
    ]);
  });

  it('getUserGlobal should call service.getScoreAndRank and wrap response', async () => {
    mockLeaderboardService.getScoreAndRank = jest.fn().mockResolvedValue({
      score: 42,
      rank: 3,
    });

    const result = await controller.getUserGlobal('user-abc');

    expect(mockLeaderboardService.getScoreAndRank).toHaveBeenCalledWith(
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

