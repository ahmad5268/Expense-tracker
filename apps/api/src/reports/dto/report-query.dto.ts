import { IsInt, IsOptional, Min, Max, IsString, Length } from 'class-validator';
import { Type } from 'class-transformer';

export class ReportQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(2020) @Max(2100)
  year?: number;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(12)
  month?: number;

  @IsOptional() @IsString() @Length(1, 50)
  categoryId?: string;
}
