import { IsString, IsInt, IsPositive, IsDateString, IsEnum, IsOptional, MaxLength } from 'class-validator';
import { TransactionType } from '@prisma/client';

export class CreateTransactionDto {
  @IsString()
  categoryId: string;

  @IsInt()
  @IsPositive()
  amount: number; // cents

  @IsEnum(TransactionType)
  type: TransactionType;

  @IsDateString()
  date: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;
}
