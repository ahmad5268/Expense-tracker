import { IsString, MinLength, MaxLength, IsISO4217CurrencyCode } from 'class-validator';

export class CreateWorkspaceDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsISO4217CurrencyCode()
  currency: string;
}
