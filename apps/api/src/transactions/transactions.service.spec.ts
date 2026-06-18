import { Test } from '@nestjs/testing';
import { TransactionsService } from './transactions.service';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';

const mockPrisma = {
  transaction: {
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  },
  category: {
    findFirst: jest.fn(),
  },
};

const mockEvents = { emit: jest.fn() };

describe('TransactionsService', () => {
  let service: TransactionsService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        TransactionsService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: EventEmitter2, useValue: mockEvents },
      ],
    }).compile();
    service = module.get(TransactionsService);
  });

  it('findAll returns paginated results', async () => {
    mockPrisma.transaction.findMany.mockResolvedValue([{ id: 't1' }]);
    mockPrisma.transaction.count.mockResolvedValue(1);
    const result = await service.findAll('w1', { page: 1, limit: 20 });
    expect(result.data).toHaveLength(1);
    expect(result.meta.total).toBe(1);
  });

  it('create returns new transaction and emits event', async () => {
    mockPrisma.category.findFirst.mockResolvedValue({ id: 'c1', workspaceId: 'w1' });
    mockPrisma.transaction.create.mockResolvedValue({ id: 't1', amount: 1000 });
    const result = await service.create('w1', 'u1', {
      categoryId: 'c1',
      amount: 1000,
      type: 'EXPENSE' as any,
      date: '2026-06-01',
    });
    expect(result.id).toBe('t1');
    expect(mockEvents.emit).toHaveBeenCalledWith('transaction.created', expect.objectContaining({ workspaceId: 'w1' }));
  });
});
