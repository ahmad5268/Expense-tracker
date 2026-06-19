import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { CacheModule } from '@nestjs/cache-manager';
import {
  QUEUE_RECURRING_TRANSACTIONS,
  QUEUE_BUDGET_ALERTS,
  QUEUE_NOTIFICATION_DELIVERY,
  QUEUE_MONTHLY_SUMMARY,
} from './queue.constants';
import { RecurringModule } from '../recurring/recurring.module';
import { TransactionsModule } from '../transactions/transactions.module';
import { BudgetsModule } from '../budgets/budgets.module';
import { RecurringProcessor } from './processors/recurring.processor';
import { BudgetAlertProcessor } from './processors/budget-alert.processor';
import { NotificationDeliveryProcessor } from './processors/notification-delivery.processor';
import { MonthlySummaryProcessor } from './processors/monthly-summary.processor';

@Module({
  imports: [
    BullModule.forRootAsync({
      useFactory: () => ({
        connection: { url: process.env.REDIS_URL ?? 'redis://localhost:6379' },
      }),
    }),
    BullModule.registerQueue(
      { name: QUEUE_RECURRING_TRANSACTIONS },
      { name: QUEUE_BUDGET_ALERTS },
      { name: QUEUE_NOTIFICATION_DELIVERY },
      { name: QUEUE_MONTHLY_SUMMARY },
    ),
    CacheModule.registerAsync({
      isGlobal: true,
      useFactory: () => ({
        ttl: 30 * 24 * 60 * 60 * 1000,
      }),
    }),
    RecurringModule,
    TransactionsModule,
    BudgetsModule,
  ],
  providers: [RecurringProcessor, BudgetAlertProcessor, NotificationDeliveryProcessor, MonthlySummaryProcessor],
})
export class JobsModule {}
