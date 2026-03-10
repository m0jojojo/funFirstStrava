import { IsNotEmpty, IsString, Matches, MaxLength } from 'class-validator';

/** DTO for POST /users/territory-color. Stores the user's chosen tile colour. */
export class TerritoryColorDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(16)
  @Matches(/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/)
  colorHex: string;
}

