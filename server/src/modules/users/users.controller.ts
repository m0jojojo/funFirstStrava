import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { RegisterUserDto } from './dto/register-user.dto';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  async register(@Body() dto: RegisterUserDto) {
    const result = await this.usersService.register(
      dto.idToken,
      dto.displayName,
      dto.email,
    );
    return {
      id: result.user.id,
      firebaseUid: result.user.firebaseUid,
      username: result.user.username,
      created: result.created,
    };
  }
}
