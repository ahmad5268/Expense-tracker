import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBudgetDto } from './dto/create-budget.dto';
import { UpdateBudgetDto } from './dto/update-budget.dto';
import { BudgetPeriod } from '@prisma/client';

@Injectable()
export class BudgetsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(workspaceId: string) {
    return this.prisma.budget.findMany({
      where: { workspaceId },
      include: { category: { select: { name: true, icon: true, color: true, type: true } } },
      orderBy: [{ year: 'desc' }, { month: 'desc' }],
    });
  }

  async create(workspaceId: string, dto: CreateBudgetDto) {
    if (dto.period === BudgetPeriod.MONTHLY && !dto.month) {
      throw new BadRequestException('month is required for MONTHLY budgets');
    }
    if (dto.period === BudgetPeriod.YEARLY && dto.month) {
      throw new BadRequestException('Yearly budget must not include month');
    }
    if (dto.month !== undefined && (dto.month < 1 || dto.month > 12)) {
      throw new BadRequestException('month must be between 1 and 12');
    }
    return this.prisma.budget.create({
      data: { ...dto, workspaceId },
      include: { category: { select: { name: true, type: true } } },
    });
  }

  async update(workspaceId: string, budgetId: string, dto: UpdateBudgetDto) {
    await this.assertOwnership(workspaceId, budgetId);
    return this.prisma.budget.update({
      where: { id: budgetId },
      data: dto,
      include: { category: { select: { name: true, type: true } } },
    });
  }

  async remove(workspaceId: string, budgetId: string) {
    await this.assertOwnership(workspaceId, budgetId);
    await this.prisma.budget.delete({ where: { id: budgetId } });
  }

  private async assertOwnership(workspaceId: string, budgetId: string) {
    const budget = await this.prisma.budget.findUnique({ where: { id: budgetId } });
    if (!budget || budget.workspaceId !== workspaceId) throw new NotFoundException('Budget not found');
  }
}
