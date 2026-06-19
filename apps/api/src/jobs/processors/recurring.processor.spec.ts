import { RecurringProcessor } from './recurring.processor';
import { getQueueToken } from '@nestjs/bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { RecurringService } from '../../recurring/recurring.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Test } from '@nestjs/testing';
import { QUEUE_BUDGET_ALERTS } from '../queue.constants';

const mockPrisma = {
  recurringRule: {
    findMany: jest.fn(),
    update: jest.fn(),
  },
  transaction: { create: jest.fn() },
  workspace: { findUnique: jest.fn() },
  $transaction: jest.fn(),
};

const mockQueue = { add: jest.fn() };
const mockEvents = { emit: jest.fn() };
const mockRecurring = { computeNextRunAt: jest.fn() };

describe('RecurringProcessor', () => {
  let processor: RecurringProcessor;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        RecurringProcessor,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: RecurringService, useValue: mockRecurring },
        { provide: EventEmitter2, useValue: mockEvents },
        { provide: getQueueToken(QUEUE_BUDGET_ALERTS), useValue: mockQueue },
      ],
    }).compile();
    processor = module.get(RecurringProcessor);
  });

  it('creates transactions for due rules and updates nextRunAt', async () => {
    const dueDate = new Date('2026-06-01');
    mockPrisma.recurringRule.findMany.mockResolvedValue([
      { id: 'r1', workspaceId: 'w1', categoryId: 'c1', amount: 5000, type: 'EXPENSE', frequency: 'MONTHLY', nextRunAt: dueDate, isActive: true },
    ]);
    mockPrisma.$transaction.mockImplementation(async (cb: (tx: typeof mockPrisma) => Promise<unknown>) => {
      mockPrisma.workspace.findUnique.mockResolvedValue({ ownerId: 'u1' });
      mockPrisma.transaction.create.mockResolvedValue({ id: 't1', workspaceId: 'w1' });
      mockRecurring.computeNextRunAt.mockReturnValue(new Date('2026-07-01'));
      return cb(mockPrisma);
    });

    await processor.processDueRules();

    expect(mockPrisma.transaction.create).toHaveBeenCalledTimes(1);
    expect(mockPrisma.recurringRule.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: 'r1' } }),
    );
    expect(mockEvents.emit).toHaveBeenCalledWith('transaction.created', expect.objectContaining({ workspaceId: 'w1' }));
  });

  it('skips rules with no due entries', async () => {
    mockPrisma.recurringRule.findMany.mockResolvedValue([]);
    await processor.processDueRules();
    expect(mockPrisma.transaction.create).not.toHaveBeenCalled();
  });
});
