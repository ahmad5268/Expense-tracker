import { IsInt, IsPositive, IsDateString, IsString, IsOptional, MaxLength, IsBoolean } from 'class-validator';

export class UpdateRecurringRuleDto {
  @IsOptional()
  @IsInt()
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
