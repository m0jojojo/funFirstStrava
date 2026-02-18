import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { User } from './user.entity';
import { REQUEST_USER_KEY } from './firebase-auth.guard';

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): User => {
    const request = ctx.switchToHttp().getRequest<Request & { user: User }>();
    return request[REQUEST_USER_KEY];
  },
);
