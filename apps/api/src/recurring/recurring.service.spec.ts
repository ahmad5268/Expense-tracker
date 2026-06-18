import { Test } from '@nestjs/testing';
import { RecurringService } from './recurring.service';
import { PrismaService } from '../prisma/prisma.service';

const mockPrisma = {
  recurringRule: { findMany: jest.fn(), create: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
};

describe('RecurringService', () => {
  let service: RecurringService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [RecurringService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get(RecurringService);
  });

  describe('computeNextRunAt', () => {
    it('returns startDate when it is in the future', () => {
      const future = new Date(Date.now() + 86400000);
      expect(service.computeNextRunAt(future, 'MONTHLY' as any)).toEqual(future);
    });

    it('advances past date by one period for MONTHLY', () => {
      const past = new Date('2026-01-01');
      const result = service.computeNextRunAt(past, 'MONTHLY' as any);
      expect(result > new Date()).toBe(true);
    });

    it('advances past date by one period for YEARLY', () => {
      const past = new Date('2025-01-01');
      const result = service.computeNextRunAt(past, 'YEARLY' as any);
      expect(result.getFullYear()).toBeGreaterThanOrEqual(2026);
    });
  });

  it('findAll returns rules for workspace', async () => {
    mockPrisma.recurringRule.findMany.mockResolvedValue([{ id: 'r1' }]);
    const result = await service.findAll('w1');
    expect(result).toHaveLength(1);
  });
});
