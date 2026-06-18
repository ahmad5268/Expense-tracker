import { IsInt, IsPositive, IsOptional } from 'class-validator';

export class UpdateBudgetDto {
  @IsOptional()
  @IsInt()
  @IsPositive()
  amount?: number;
}
