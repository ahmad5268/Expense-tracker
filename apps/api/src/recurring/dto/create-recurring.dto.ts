import { IsString, IsInt, IsPositive, IsEnum, IsDateString, IsOptional, MaxLength } from 'class-validator';
import { TransactionType, Frequency } from '@prisma/client';

export class CreateRecurringRuleDto {
  @IsString()
  categoryId: string;

  @IsInt()
  @IsPositive()
  amount: number; // cents

  @IsEnum(TransactionType)
  type: TransactionType;

  @IsEnum(Frequency)
  frequency: Frequency;

  @IsDateString()
  startDate: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;
}
