import { User } from './user.entity';

describe('User entity', () => {
  it('should be constructible with required fields', () => {
    const user = new User();
    user.firebaseUid = 'firebase-uid';
    user.username = 'test-user';

    expect(user.firebaseUid).toBe('firebase-uid');
    expect(user.username).toBe('test-user');
  });
});

