import { IsArray, IsNumber, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class PathPointDto {
  @IsNumber()
  lat!: number;

  @IsNumber()
  lng!: number;

  @IsNumber()
  t!: number;
}

export class CreateRunDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PathPointDto)
  path!: PathPointDto[];
}
