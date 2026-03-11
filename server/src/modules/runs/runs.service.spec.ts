import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { RunsService } from './runs.service';
import { Run } from './run.entity';
import { TilesService } from '../tiles/tiles.service';
import { LeaderboardService } from '../leaderboard/leaderboard.service';

describe('RunsService + Leaderboard integration (Phase 5)', () => {
  let service: RunsService;
  const mockRepo = {
    create: jest.fn((v) => v),
    save: jest.fn(async (v) => v),
    find: jest.fn(),
  };
  const mockTilesService = {
    captureTilesByPath: jest.fn().mockResolvedValue(3),
  };
  const mockLeaderboardService = {
    updateScore: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        RunsService,
        { provide: TilesService, useValue: mockTilesService },
        { provide: LeaderboardService, useValue: mockLeaderboardService },
        {
          provide: getRepositoryToken(Run),
          useValue: mockRepo,
        },
      ],
    }).compile();

    service = module.get<RunsService>(RunsService);
  });

  it('should call leaderboard.updateScore after saving run', async () => {
    const fakeUser: any = { id: 'user-123' };
    const path = [
      { lat: 1, lng: 1, t: 0 },
      { lat: 1, lng: 1.0001, t: 60_000 }, // ~11m in 60s ⇒ well below max speed
      { lat: 1, lng: 1.0002, t: 120_000 },
    ];

    await service.create(fakeUser, path);

    expect(mockTilesService.captureTilesByPath).toHaveBeenCalled();
    expect(mockLeaderboardService.updateScore).toHaveBeenCalledWith(
      'user-123',
      3,
      { type: 'global' },
    );
  });
});

