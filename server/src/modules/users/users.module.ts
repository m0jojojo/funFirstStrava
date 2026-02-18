import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { FirebaseAuthGuard } from './firebase-auth.guard';
import { FirebaseTokenService } from './firebase-token.service';
import { User } from './user.entity';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({
  imports: [TypeOrmModule.forFeature([User])],
  controllers: [UsersController],
  providers: [FirebaseTokenService, UsersService, FirebaseAuthGuard],
  exports: [UsersService, FirebaseAuthGuard, FirebaseTokenService],
})
export class UsersModule {}
