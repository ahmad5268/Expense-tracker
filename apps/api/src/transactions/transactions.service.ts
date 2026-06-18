import { Injectable, NotFoundException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { UpdateTransactionDto } from './dto/update-transaction.dto';
import { TransactionFilterDto } from './dto/transaction-query.dto';

@Injectable()
export class TransactionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  async findAll(workspaceId: string, filter: TransactionFilterDto) {
    const { from, to, type, categoryId, page = 1, limit = 20 } = filter;
    const where = {
      workspaceId,
      ...(type && { type }),
      ...(categoryId && { categoryId }),
      ...(from || to
        ? { date: { ...(from && { gte: new Date(from) }), ...(to && { lte: new Date(to) }) } }
        : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.transaction.findMany({
        where,
        include: {
          category: { select: { name: true, icon: true, color: true } },
          user: { select: { name: true } },
        },
        orderBy: { date: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.transaction.count({ where }),
    ]);

    return { data, meta: { total, page, limit, totalPages: Math.ceil(total / limit) } };
  }

  async create(workspaceId: string, userId: string, dto: CreateTransactionDto) {
    await this.assertCategoryInWorkspace(workspaceId, dto.categoryId);
    const transaction = await this.prisma.transaction.create({
      data: { ...dto, date: new Date(dto.date), workspaceId, userId },
      include: { category: true },
    });

    this.events.emit('transaction.created', { workspaceId, transactionId: transaction.id });
    return transaction;
  }

  async update(workspaceId: string, transactionId: string, dto: UpdateTransactionDto) {
    await this.assertOwnership(workspaceId, transactionId);
    if (dto.categoryId) await this.assertCategoryInWorkspace(workspaceId, dto.categoryId);
    return this.prisma.transaction.update({
      where: { id: transactionId },
      data: { ...dto, ...(dto.date && { date: new Date(dto.date) }) },
      include: { category: true },
    });
  }

  async remove(workspaceId: string, transactionId: string) {
    await this.assertOwnership(workspaceId, transactionId);
    await this.prisma.transaction.delete({ where: { id: transactionId } });
  }

  private async assertOwnership(workspaceId: string, transactionId: string) {
    const tx = await this.prisma.transaction.findUnique({ where: { id: transactionId } });
    if (!tx || tx.workspaceId !== workspaceId) throw new NotFoundException('Transaction not found');
  }

  private async assertCategoryInWorkspace(workspaceId: string, categoryId: string) {
    const category = await this.prisma.category.findFirst({ where: { id: categoryId, workspaceId } });
    if (!category) throw new NotFoundException('Category not found in this workspace');
  }
}
