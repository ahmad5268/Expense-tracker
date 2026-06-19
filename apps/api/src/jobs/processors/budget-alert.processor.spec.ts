import { Test } from '@nestjs/testing';
import { BudgetAlertProcessor } from './budget-alert.processor';
import { PrismaService } from '../../prisma/prisma.service';
import { getQueueToken } from '@nestjs/bullmq';
import { QUEUE_NOTIFICATION_DELIVERY } from '../queue.constants';
import { CACHE_MANAGER } from '@nestjs/cache-manager';

const mockPrisma = {
  budget: { findMany: jest.fn() },
  transaction: { aggregate: jest.fn() },
  workspaceMember: { findMany: jest.fn() },
};
const mockQueue = { add: jest.fn() };
const mockCache = { get: jest.fn(), set: jest.fn() };

describe('BudgetAlertProcessor', () => {
  let processor: BudgetAlertProcessor;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        BudgetAlertProcessor,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: getQueueToken(QUEUE_NOTIFICATION_DELIVERY), useValue: mockQueue },
        { provide: CACHE_MANAGER, useValue: mockCache },
      ],
    }).compile();
    processor = module.get(BudgetAlertProcessor);
  });

  it('queues notification when spend exceeds 80% threshold', async () => {
    mockPrisma.budget.findMany.mockResolvedValue([
      { id: 'b1', workspaceId: 'w1', categoryId: 'c1', amount: 10000, period: 'MONTHLY', year: 2026, month: 6 },
    ]);
    mockPrisma.transaction.aggregate.mockResolvedValue({ _sum: { amount: 8500 } });
    mockPrisma.workspaceMember.findMany.mockResolvedValue([{ userId: 'u1', user: { email: 'u@test.com' } }]);
    mockCache.get.mockResolvedValue(null);

    await processor.checkBudget({ workspaceId: 'w1', transactionId: 't1' });

    expect(mockQueue.add).toHaveBeenCalled();
    expect(mockCache.set).toHaveBeenCalled();
  });

  it('skips notification when dedup key exists', async () => {
    mockPrisma.budget.findMany.mockResolvedValue([
      { id: 'b1', workspaceId: 'w1', categoryId: 'c1', amount: 10000, period: 'MONTHLY', year: 2026, month: 6 },
    ]);
    mockPrisma.transaction.aggregate.mockResolvedValue({ _sum: { amount: 8500 } });
    mockPrisma.workspaceMember.findMany.mockResolvedValue([{ userId: 'u1', user: { email: 'u@test.com' } }]);
    mockCache.get.mockResolvedValue('1');

    await processor.checkBudget({ workspaceId: 'w1', transactionId: 't1' });

    expect(mockQueue.add).not.toHaveBeenCalled();
  });

  it('does not alert when under 80%', async () => {
    mockPrisma.budget.findMany.mockResolvedValue([
      { id: 'b1', workspaceId: 'w1', categoryId: null, amount: 10000, period: 'MONTHLY', year: 2026, month: 6 },
    ]);
    mockPrisma.transaction.aggregate.mockResolvedValue({ _sum: { amount: 7000 } });
    mockPrisma.workspaceMember.findMany.mockResolvedValue([{ userId: 'u1', user: { email: 'u@test.com' } }]);
    mockCache.get.mockResolvedValue(null);

    await processor.checkBudget({ workspaceId: 'w1', transactionId: 't1' });

    expect(mockQueue.add).not.toHaveBeenCalled();
  });
});
