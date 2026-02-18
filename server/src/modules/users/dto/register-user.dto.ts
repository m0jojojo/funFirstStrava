import { IsOptional, IsString, MinLength } from 'class-validator';

/** DTO for POST /users/register. Mobile sends Firebase ID token after Google sign-in. */
export class RegisterUserDto {
  /** Firebase ID token from Firebase Auth (e.g. currentUser.getIdToken()). */
  @IsString()
  @MinLength(10)
  idToken: string;

  @IsOptional()
  @IsString()
  displayName?: string;

  @IsOptional()
  @IsString()
  email?: string;
}
