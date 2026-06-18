import { Test } from '@nestjs/testing';
import { BudgetsService } from './budgets.service';
import { PrismaService } from '../prisma/prisma.service';
import { BadRequestException } from '@nestjs/common';

const mockPrisma = {
  budget: { findMany: jest.fn(), create: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
};

describe('BudgetsService', () => {
  let service: BudgetsService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [BudgetsService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get(BudgetsService);
  });

  it('throws BadRequestException when MONTHLY budget has no month', async () => {
    await expect(service.create('w1', { amount: 100000, period: 'MONTHLY' as any, year: 2026 }))
      .rejects.toThrow(BadRequestException);
  });

  it('throws BadRequestException when YEARLY budget has month set', async () => {
    await expect(service.create('w1', { amount: 1000000, period: 'YEARLY' as any, year: 2026, month: 6 }))
      .rejects.toThrow(BadRequestException);
  });

  it('throws BadRequestException when month is 0', async () => {
    await expect(service.create('w1', { amount: 100000, period: 'MONTHLY' as any, year: 2026, month: 0 }))
      .rejects.toThrow(BadRequestException);
  });

  it('throws BadRequestException when month is 13', async () => {
    await expect(service.create('w1', { amount: 100000, period: 'MONTHLY' as any, year: 2026, month: 13 }))
      .rejects.toThrow(BadRequestException);
  });

  it('creates YEARLY budget without month', async () => {
    mockPrisma.budget.create.mockResolvedValue({ id: 'b1', amount: 1000000 });
    const result = await service.create('w1', { amount: 1000000, period: 'YEARLY' as any, year: 2026 });
    expect(result.id).toBe('b1');
  });

  it('findAll returns budgets for workspace', async () => {
    mockPrisma.budget.findMany.mockResolvedValue([{ id: 'b1' }]);
    const result = await service.findAll('w1');
    expect(result).toHaveLength(1);
  });

  it('workspace can have both total and category-specific budgets in same month', async () => {
    mockPrisma.budget.create.mockResolvedValueOnce({ id: 'b-total', categoryId: null, amount: 500000 });
    mockPrisma.budget.create.mockResolvedValueOnce({ id: 'b-food', categoryId: 'c1', amount: 100000 });

    const total = await service.create('w1', { amount: 500000, period: 'MONTHLY' as any, year: 2026, month: 6 });
    const food = await service.create('w1', { amount: 100000, period: 'MONTHLY' as any, year: 2026, month: 6, categoryId: 'c1' });

    expect(total.id).toBe('b-total');
    expect(food.id).toBe('b-food');
  });
});
