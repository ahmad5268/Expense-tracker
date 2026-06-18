import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateRecurringRuleDto } from './dto/create-recurring.dto';
import { UpdateRecurringRuleDto } from './dto/update-recurring.dto';
import { Frequency } from '@prisma/client';
import { addDays, addWeeks, addMonths, addYears, isFuture } from 'date-fns';

@Injectable()
export class RecurringService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(workspaceId: string) {
    return this.prisma.recurringRule.findMany({
      where: { workspaceId },
      include: { category: { select: { name: true, icon: true, color: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  create(workspaceId: string, dto: CreateRecurringRuleDto) {
    const startDate = new Date(dto.startDate);
    const nextRunAt = this.computeNextRunAt(startDate, dto.frequency);
    return this.prisma.recurringRule.create({
      data: {
        ...dto,
        startDate,
        endDate: dto.endDate ? new Date(dto.endDate) : undefined,
        workspaceId,
        nextRunAt,
      },
      include: { category: true },
    });
  }

  async update(workspaceId: string, ruleId: string, dto: UpdateRecurringRuleDto) {
    await this.assertOwnership(workspaceId, ruleId);
    return this.prisma.recurringRule.update({
      where: { id: ruleId },
      data: { ...dto, ...(dto.endDate && { endDate: new Date(dto.endDate) }) },
      include: { category: true },
    });
  }

  async remove(workspaceId: string, ruleId: string) {
    await this.assertOwnership(workspaceId, ruleId);
    await this.prisma.recurringRule.delete({ where: { id: ruleId } });
  }

  computeNextRunAt(startDate: Date, frequency: Frequency): Date {
    if (isFuture(startDate)) return startDate;

    let next = new Date(startDate);
    while (!isFuture(next)) {
      switch (frequency) {
        case Frequency.DAILY:   next = addDays(next, 1);   break;
        case Frequency.WEEKLY:  next = addWeeks(next, 1);  break;
        case Frequency.MONTHLY: next = addMonths(next, 1); break;
        case Frequency.YEARLY:  next = addYears(next, 1);  break;
      }
    }
    return next;
  }

  private async assertOwnership(workspaceId: string, ruleId: string) {
    const rule = await this.prisma.recurringRule.findUnique({ where: { id: ruleId } });
    if (!rule || rule.workspaceId !== workspaceId) throw new NotFoundException('Recurring rule not found');
  }
}
