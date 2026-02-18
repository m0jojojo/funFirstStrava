import { HttpStatus } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { RegisterResult } from './users.service.interface';
import { User } from './user.entity';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

describe('UsersController', () => {
  let controller: UsersController;
  let usersService: jest.Mocked<UsersService>;

  const mockUser: User = {
    id: 'uuid-1',
    firebaseUid: 'firebase-uid',
    username: 'testuser',
    createdAt: new Date(),
  };

  beforeEach(async () => {
    const mockRegister = jest.fn().mockResolvedValue({
      user: mockUser,
      created: true,
    } as RegisterResult);
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: { register: mockRegister },
        },
      ],
    }).compile();

    controller = module.get<UsersController>(UsersController);
    usersService = module.get(UsersService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('POST /users/register returns 201 and user info', async () => {
    const result = await controller.register({
      idToken: 'valid-firebase-id-token',
      displayName: 'Test User',
    });
    expect(usersService.register).toHaveBeenCalledWith(
      'valid-firebase-id-token',
      'Test User',
      undefined,
    );
    expect(result).toEqual({
      id: mockUser.id,
      firebaseUid: mockUser.firebaseUid,
      username: mockUser.username,
      created: true,
    });
  });
});
