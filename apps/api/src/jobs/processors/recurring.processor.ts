import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { RecurringService } from '../../recurring/recurring.service';
import { QUEUE_BUDGET_ALERTS } from '../queue.constants';

@Injectable()
export class RecurringProcessor {
  private readonly logger = new Logger(RecurringProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly recurringService: RecurringService,
    private readonly events: EventEmitter2,
    @InjectQueue(QUEUE_BUDGET_ALERTS) private readonly budgetQueue: Queue,
  ) {}

  @Cron('0 0 * * *', { name: 'process-due-recurring-rules' })
  async processDueRules() {
    const dueRules = await this.prisma.recurringRule.findMany({
      where: { nextRunAt: { lte: new Date() }, isActive: true },
    });

    this.logger.log(`Processing ${dueRules.length} due recurring rules`);

    for (const rule of dueRules) {
      try {
        const transaction = await this.prisma.$transaction(async (tx) => {
          const workspace = await tx.workspace.findUnique({
            where: { id: rule.workspaceId },
            select: { ownerId: true },
          });
          const created = await tx.transaction.create({
            data: {
              workspaceId: rule.workspaceId,
              userId: workspace!.ownerId,
              categoryId: rule.categoryId,
              amount: rule.amount,
              type: rule.type,
              description: rule.description ?? undefined,
              date: new Date(),
              recurringRuleId: rule.id,
            },
          });
          const nextRunAt = this.recurringService.computeNextRunAt(rule.nextRunAt, rule.frequency);
          await tx.recurringRule.update({ where: { id: rule.id }, data: { nextRunAt } });
          return created;
        });
        this.events.emit('transaction.created', { workspaceId: rule.workspaceId, transactionId: transaction.id });
      } catch (err) {
        this.logger.error(`Failed to process rule ${rule.id}`, err);
      }
    }
  }
}
