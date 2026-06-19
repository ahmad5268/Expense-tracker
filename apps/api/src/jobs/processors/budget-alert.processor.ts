import { Injectable, Logger, Inject } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';
import { PrismaService } from '../../prisma/prisma.service';
import { QUEUE_NOTIFICATION_DELIVERY, JOB_SEND_IN_APP, JOB_SEND_EMAIL, JOB_SEND_PUSH } from '../queue.constants';
import { BudgetPeriod } from '@prisma/client';

const ALERT_THRESHOLDS = [80, 100];

@Injectable()
export class BudgetAlertProcessor {
  private readonly logger = new Logger(BudgetAlertProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(QUEUE_NOTIFICATION_DELIVERY) private readonly notificationQueue: Queue,
    @Inject(CACHE_MANAGER) private readonly cache: Cache,
  ) {}

  @OnEvent('transaction.created')
  async checkBudget(payload: { workspaceId: string; transactionId: string }) {
    const { workspaceId } = payload;
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;

    const budgets = await this.prisma.budget.findMany({ where: { workspaceId } });

    for (const budget of budgets) {
      const where = {
        workspaceId,
        type: 'EXPENSE' as const,
        date: {
          gte: budget.period === BudgetPeriod.MONTHLY ? new Date(year, month - 1, 1) : new Date(year, 0, 1),
          lt: budget.period === BudgetPeriod.MONTHLY ? new Date(year, month, 1) : new Date(year + 1, 0, 1),
        },
        ...(budget.categoryId && { categoryId: budget.categoryId }),
      };

      const agg = await this.prisma.transaction.aggregate({ where, _sum: { amount: true } });
      const spent = agg._sum.amount ?? 0;
      const percentUsed = (spent / budget.amount) * 100;

      for (const threshold of ALERT_THRESHOLDS) {
        if (percentUsed < threshold) continue;

        const dedupKey = `budget:alert:${workspaceId}:${budget.id}:${year}-${month}:${threshold}`;
        const alreadySent = await this.cache.get(dedupKey);
        if (alreadySent) continue;

        await this.cache.set(dedupKey, '1', 30 * 24 * 60 * 60 * 1000);

        const members = await this.prisma.workspaceMember.findMany({
          where: { workspaceId },
          include: { user: { select: { email: true } } },
        });

        for (const member of members) {
          const notifPayload = {
            userId: member.userId,
            type: 'BUDGET_ALERT',
            payload: { budgetId: budget.id, workspaceId, threshold, percentUsed: Math.round(percentUsed), spent, limit: budget.amount },
          };

          await Promise.all([
            this.notificationQueue.add(JOB_SEND_IN_APP, notifPayload, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } }),
            this.notificationQueue.add(JOB_SEND_EMAIL, {
              ...notifPayload,
              to: member.user.email,
            }, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } }),
            this.notificationQueue.add(JOB_SEND_PUSH, notifPayload, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } }),
          ]);
        }

        this.logger.log(`Budget alert queued: ${budget.id} at ${threshold}% threshold`);
      }
    }
  }
}
