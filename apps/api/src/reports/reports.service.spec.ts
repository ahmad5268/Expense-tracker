import { Test } from '@nestjs/testing';
import { ReportsService } from './reports.service';
import { PrismaService } from '../prisma/prisma.service';

const mockPrisma = { $queryRaw: jest.fn() };

describe('ReportsService', () => {
  let service: ReportsService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        ReportsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();
    service = module.get(ReportsService);
  });

  describe('getSummary', () => {
    it('returns total income, expense, and net for a period', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        { type: 'INCOME', total: BigInt(100000) },
        { type: 'EXPENSE', total: BigInt(75000) },
      ]);
      const result = await service.getSummary('w1', 2026, 6);
      expect(result.totalIncome).toBe(100000);
      expect(result.totalExpense).toBe(75000);
      expect(result.net).toBe(25000);
    });

    it('handles empty month (all zeros)', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([]);
      const result = await service.getSummary('w1', 2026, 6);
      expect(result.totalIncome).toBe(0);
      expect(result.totalExpense).toBe(0);
      expect(result.net).toBe(0);
    });
  });

  describe('getByCategory', () => {
    it('returns spending grouped by category', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        { categoryId: 'c1', categoryName: 'Food', total: BigInt(30000), count: BigInt(5) },
      ]);
      const result = await service.getByCategory('w1', 2026, 6);
      expect(result[0].total).toBe(30000);
      expect(result[0].count).toBe(5);
    });
  });

  describe('getTrends', () => {
    it('returns monthly totals for the given year', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        { month: 1, type: 'INCOME', total: BigInt(50000) },
        { month: 1, type: 'EXPENSE', total: BigInt(40000) },
      ]);
      const result = await service.getTrends('w1', 2026);
      expect(result).toHaveLength(2);
      expect(result[0].total).toBe(50000);
    });
  });

  describe('getBudgetVsActual', () => {
    it('returns budget vs actual spend per category', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        {
          budgetId: 'b1',
          categoryId: 'c1',
          categoryName: 'Housing',
          budgetAmount: BigInt(120000),
          actualAmount: BigInt(90000),
        },
      ]);
      const result = await service.getBudgetVsActual('w1', 2026, 6);
      expect(result[0].budgetAmount).toBe(120000);
      expect(result[0].actualAmount).toBe(90000);
    });
  });
});
