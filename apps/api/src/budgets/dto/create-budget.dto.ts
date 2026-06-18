import { IsInt, IsPositive, IsEnum, IsOptional, IsString, IsNumber, Min, Max } from 'class-validator';
import { BudgetPeriod } from '@prisma/client';

export class CreateBudgetDto {
  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsInt()
  @IsPositive()
  amount: number; // cents

  @IsEnum(BudgetPeriod)
  period: BudgetPeriod;

  @IsNumber()
  @Min(2020)
  @Max(2100)
  year: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(12)
  month?: number;
}
