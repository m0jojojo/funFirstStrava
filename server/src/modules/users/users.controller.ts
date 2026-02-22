import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { RegisterUserDto } from './dto/register-user.dto';
import { FcmTokenDto } from './dto/fcm-token.dto';
import { FirebaseAuthGuard } from './firebase-auth.guard';
import { CurrentUser } from './user.decorator';
import { User } from './user.entity';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post('fcm-token')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(FirebaseAuthGuard)
  async registerFcmToken(
    @CurrentUser() user: User,
    @Body() dto: FcmTokenDto,
  ): Promise<void> {
    await this.usersService.updateFcmToken(user.id, dto.fcmToken);
  }

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
