import { IsString, IsOptional, MinLength, MaxLength, IsISO4217CurrencyCode } from 'class-validator';

export class UpdateWorkspaceDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsISO4217CurrencyCode()
  currency?: string;
}
