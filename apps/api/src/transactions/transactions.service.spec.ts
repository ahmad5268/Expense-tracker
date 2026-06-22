import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { TransactionsService } from './transactions.service';
import { PrismaService } from '../prisma/prisma.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { TransactionType } from '@prisma/client';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const WORKSPACE_ID = 'w1';
const USER_ID = 'u1';
const TX_ID = 'tx1';
const CAT_ID = 'c1';

const fakeCategory = { id: CAT_ID, workspaceId: WORKSPACE_ID, name: 'Food', type: 'EXPENSE' };
const fakeTransaction = {
  id: TX_ID,
  workspaceId: WORKSPACE_ID,
  userId: USER_ID,
  categoryId: CAT_ID,
  amount: 1000,
  type: TransactionType.EXPENSE,
  date: new Date('2026-06-01'),
  description: null,
  recurringRuleId: null,
  createdAt: new Date(),
};

const createDto = {
  categoryId: CAT_ID,
  amount: 1000,
  type: TransactionType.EXPENSE,
  date: '2026-06-01',
};

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // findAll
  // -------------------------------------------------------------------------

  describe('findAll', () => {
    it('returns paginated results with meta', async () => {
      mockPrisma.transaction.findMany.mockResolvedValue([fakeTransaction]);
      mockPrisma.transaction.count.mockResolvedValue(1);

      const result = await service.findAll(WORKSPACE_ID, { page: 1, limit: 20 });

      expect(result.data).toHaveLength(1);
      expect(result.data[0].id).toBe(TX_ID);
      expect(result.meta).toEqual({ total: 1, page: 1, limit: 20, totalPages: 1 });
    });

    it('applies type filter to WHERE clause', async () => {
      mockPrisma.transaction.findMany.mockResolvedValue([]);
      mockPrisma.transaction.count.mockResolvedValue(0);

      await service.findAll(WORKSPACE_ID, { type: TransactionType.EXPENSE, page: 1, limit: 20 });

      const whereArg = mockPrisma.transaction.findMany.mock.calls[0][0].where;
      expect(whereArg.type).toBe(TransactionType.EXPENSE);
    });

    it('applies categoryId filter to WHERE clause', async () => {
      mockPrisma.transaction.findMany.mockResolvedValue([]);
      mockPrisma.transaction.count.mockResolvedValue(0);

      await service.findAll(WORKSPACE_ID, { categoryId: CAT_ID, page: 1, limit: 20 });

      const whereArg = mockPrisma.transaction.findMany.mock.calls[0][0].where;
      expect(whereArg.categoryId).toBe(CAT_ID);
    });

    it('applies date range filter to WHERE clause', async () => {
      mockPrisma.transaction.findMany.mockResolvedValue([]);
      mockPrisma.transaction.count.mockResolvedValue(0);

      await service.findAll(WORKSPACE_ID, {
        from: '2026-06-01',
        to: '2026-06-30',
        page: 1,
        limit: 20,
      });

      const whereArg = mockPrisma.transaction.findMany.mock.calls[0][0].where;
      expect(whereArg.date.gte).toEqual(new Date('2026-06-01'));
      expect(whereArg.date.lte).toEqual(new Date('2026-06-30'));
    });

    it('respects page and limit for pagination', async () => {
      mockPrisma.transaction.findMany.mockResolvedValue([]);
      mockPrisma.transaction.count.mockResolvedValue(25);

      const result = await service.findAll(WORKSPACE_ID, { page: 2, limit: 10 });

      const findManyCall = mockPrisma.transaction.findMany.mock.calls[0][0];
      expect(findManyCall.skip).toBe(10); // (page-1) * limit
      expect(findManyCall.take).toBe(10);
      expect(result.meta.totalPages).toBe(3);
    });

    it('computes totalPages correctly when total is not a multiple of limit', async () => {
      mockPrisma.transaction.findMany.mockResolvedValue([]);
      mockPrisma.transaction.count.mockResolvedValue(21);

      const result = await service.findAll(WORKSPACE_ID, { page: 1, limit: 20 });

      expect(result.meta.totalPages).toBe(2);
    });

    it('returns empty data array when no transactions match', async () => {
      mockPrisma.transaction.findMany.mockResolvedValue([]);
      mockPrisma.transaction.count.mockResolvedValue(0);

      const result = await service.findAll(WORKSPACE_ID, { page: 1, limit: 20 });

      expect(result.data).toEqual([]);
      expect(result.meta.total).toBe(0);
      expect(result.meta.totalPages).toBe(0);
    });
  });

  // -------------------------------------------------------------------------
  // create
  // -------------------------------------------------------------------------

  describe('create', () => {
    it('creates a transaction and emits transaction.created event', async () => {
      mockPrisma.category.findFirst.mockResolvedValue(fakeCategory);
      mockPrisma.transaction.create.mockResolvedValue(fakeTransaction);

      const result = await service.create(WORKSPACE_ID, USER_ID, createDto);

      expect(result.id).toBe(TX_ID);
      expect(mockPrisma.transaction.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            workspaceId: WORKSPACE_ID,
            userId: USER_ID,
            categoryId: CAT_ID,
            amount: 1000,
          }),
        }),
      );
      expect(mockEvents.emit).toHaveBeenCalledWith(
        'transaction.created',
        expect.objectContaining({ workspaceId: WORKSPACE_ID, transactionId: TX_ID }),
      );
    });

    it('converts date string to Date object before saving', async () => {
      mockPrisma.category.findFirst.mockResolvedValue(fakeCategory);
      mockPrisma.transaction.create.mockResolvedValue(fakeTransaction);

      await service.create(WORKSPACE_ID, USER_ID, createDto);

      const savedData = mockPrisma.transaction.create.mock.calls[0][0].data;
      expect(savedData.date).toBeInstanceOf(Date);
    });

    it('throws NotFoundException when category does not belong to workspace', async () => {
      mockPrisma.category.findFirst.mockResolvedValue(null);

      await expect(service.create(WORKSPACE_ID, USER_ID, createDto)).rejects.toThrow(
        NotFoundException,
      );
      expect(mockPrisma.transaction.create).not.toHaveBeenCalled();
      expect(mockEvents.emit).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // update
  // -------------------------------------------------------------------------

  describe('update', () => {
    it('updates a transaction and returns the result', async () => {
      const updated = { ...fakeTransaction, amount: 2000 };
      mockPrisma.transaction.findUnique.mockResolvedValue(fakeTransaction);
      mockPrisma.transaction.update.mockResolvedValue(updated);

      const result = await service.update(WORKSPACE_ID, TX_ID, { amount: 2000 });

      expect(result.amount).toBe(2000);
      expect(mockPrisma.transaction.update).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: TX_ID } }),
      );
    });

    it('converts date string to Date when date is being updated', async () => {
      mockPrisma.transaction.findUnique.mockResolvedValue(fakeTransaction);
      mockPrisma.transaction.update.mockResolvedValue(fakeTransaction);

      await service.update(WORKSPACE_ID, TX_ID, { date: '2026-07-01' });

      const updatedData = mockPrisma.transaction.update.mock.calls[0][0].data;
      expect(updatedData.date).toBeInstanceOf(Date);
    });

    it('validates category belongs to workspace when categoryId is updated', async () => {
      mockPrisma.transaction.findUnique.mockResolvedValue(fakeTransaction);
      mockPrisma.category.findFirst.mockResolvedValue(null);

      await expect(
        service.update(WORKSPACE_ID, TX_ID, { categoryId: 'other-cat' }),
      ).rejects.toThrow(NotFoundException);
    });

    it('throws NotFoundException when transaction does not exist', async () => {
      mockPrisma.transaction.findUnique.mockResolvedValue(null);

      await expect(service.update(WORKSPACE_ID, TX_ID, { amount: 500 })).rejects.toThrow(
        NotFoundException,
      );
      expect(mockPrisma.transaction.update).not.toHaveBeenCalled();
    });

    it('throws NotFoundException when transaction belongs to a different workspace', async () => {
      mockPrisma.transaction.findUnique.mockResolvedValue({
        ...fakeTransaction,
        workspaceId: 'other-workspace',
      });

      await expect(service.update(WORKSPACE_ID, TX_ID, { amount: 500 })).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  // -------------------------------------------------------------------------
  // remove
  // -------------------------------------------------------------------------

  describe('remove', () => {
    it('deletes the transaction when it belongs to the workspace', async () => {
      mockPrisma.transaction.findUnique.mockResolvedValue(fakeTransaction);
      mockPrisma.transaction.delete.mockResolvedValue(fakeTransaction);

      await service.remove(WORKSPACE_ID, TX_ID);

      expect(mockPrisma.transaction.delete).toHaveBeenCalledWith({ where: { id: TX_ID } });
    });

    it('throws NotFoundException when transaction does not exist', async () => {
      mockPrisma.transaction.findUnique.mockResolvedValue(null);

      await expect(service.remove(WORKSPACE_ID, TX_ID)).rejects.toThrow(NotFoundException);
      expect(mockPrisma.transaction.delete).not.toHaveBeenCalled();
    });

    it('throws NotFoundException when transaction belongs to a different workspace', async () => {
      mockPrisma.transaction.findUnique.mockResolvedValue({
        ...fakeTransaction,
        workspaceId: 'other-workspace',
      });

      await expect(service.remove(WORKSPACE_ID, TX_ID)).rejects.toThrow(NotFoundException);
      expect(mockPrisma.transaction.delete).not.toHaveBeenCalled();
    });
  });
});
