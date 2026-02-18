import { User } from './user.entity';

export interface RegisterResult {
  user: User;
  created: boolean;
}

export interface IUsersService {
  register(idToken: string, displayName?: string, email?: string): Promise<RegisterResult>;
}
