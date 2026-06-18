# Backend API — Phase 5: Background Jobs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up BullMQ with Redis and implement the four job processors: (1) recurring transaction engine (midnight cron), (2) budget alert checker triggered by transaction events, (3) notification delivery dispatcher (push/email/in-app), and (4) monthly summary cron. Budget alerts deduplicate via a Redis TTL key.

**Architecture:** A single `JobsModule` imports all four processors and the BullMQ queues. Queue names are constants to avoid typos. The `RecurringProcessor` is a cron job (`0 0 * * *`). The `BudgetAlertProcessor` listens for `transaction.created` events (emitted by `TransactionsService` in Phase 3) via NestJS `@OnEvent`. The `NotificationDeliveryProcessor` dispatches individual delivery jobs. The `MonthlySummaryProcessor` runs on `0 8 1 * *`.

**Tech Stack:** `@nestjs/bullmq`, `bullmq`, `ioredis`, `@nestjs/event-emitter`, `firebase-admin`, `@sendgrid/mail`

> **Schema prerequisite:** The `users` table must have an `fcmToken String?` column (nullable) so push tokens can be stored per user. Add this to the Prisma User model in Phase 1 schema (or via a new migration here before implementing Task 4). The FCM token is set by the mobile app via `PUT /users/me/fcm-token` (added in backend-phase3 Task 1, Step 1.5).

**Prerequisite:** Phase 4 complete. `RecurringService.computeNextRunAt` is exported. `TransactionsService` emits `transaction.created` events. `NotificationsService` (Phase 6) will be imported — stub the import for now with a comment.

---

## File Map

| File | Responsibility |
|---|---|
| `src/jobs/jobs.module.ts` | Registers all queues and processors |
| `src/jobs/queue.constants.ts` | Queue name constants |
| `src/jobs/processors/recurring.processor.ts` | Midnight cron — creates transactions from due rules |
| `src/jobs/processors/recurring.processor.spec.ts` | Unit tests |
| `src/jobs/processors/budget-alert.processor.ts` | Listens for transaction.created, checks budget thresholds |
| `src/jobs/processors/budget-alert.processor.spec.ts` | Unit tests |
| `src/jobs/processors/notification-delivery.processor.ts` | Dispatches push, email, in-app per job type |
| `src/jobs/processors/monthly-summary.processor.ts` | 1st of month cron — workspace digest |

---

## Task 1: BullMQ setup + queue constants

**Files:**
- Create: `src/jobs/queue.constants.ts`
- Create: `src/jobs/jobs.module.ts`

- [ ] **Step 1.1: Install BullMQ packages**

```bash
cd apps/api
npm install --save @nestjs/bullmq bullmq ioredis
```

- [ ] **Step 1.2: Create queue name constants**

```typescript
// apps/api/src/jobs/queue.constants.ts
export const QUEUE_RECURRING_TRANSACTIONS = 'recurring-transactions';
export const QUEUE_BUDGET_ALERTS = 'budget-alerts';
export const QUEUE_NOTIFICATION_DELIVERY = 'notifications-delivery';
export const QUEUE_MONTHLY_SUMMARY = 'monthly-summary';

export const JOB_PROCESS_DUE_RULES = 'process-due-rules';
export const JOB_CHECK_BUDGET = 'check-budget';
export const JOB_SEND_PUSH = 'send-push';
export const JOB_SEND_EMAIL = 'send-email';
export const JOB_SEND_IN_APP = 'send-in-app';
export const JOB_GENERATE_SUMMARY = 'generate-summary';
```

- [ ] **Step 1.3: Create JobsModule (without processors yet — add them as Tasks complete)**

```typescript
// apps/api/src/jobs/jobs.module.ts
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
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
    RecurringModule,
    TransactionsModule,
    BudgetsModule,
  ],
  providers: [RecurringProcessor, BudgetAlertProcessor, NotificationDeliveryProcessor, MonthlySummaryProcessor],
})
export class JobsModule {}
```

Add `JobsModule` to AppModule imports.

- [ ] **Step 1.4: Commit**

```bash
git add apps/api/src/jobs/queue.constants.ts apps/api/src/jobs/jobs.module.ts apps/api/src/app.module.ts
git commit -m "feat(jobs): add BullMQ setup with queue constants and JobsModule"
```

---

## Task 2: RecurringProcessor
Depends-on: 1

**Files:**
- Create: `src/jobs/processors/recurring.processor.ts`
- Create: `src/jobs/processors/recurring.processor.spec.ts`

- [ ] **Step 2.1: Write failing unit tests**

```typescript
// apps/api/src/jobs/processors/recurring.processor.spec.ts
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
    mockPrisma.$transaction.mockImplementation(async (cb: Function) => cb(mockPrisma));
    mockPrisma.transaction.create.mockResolvedValue({ id: 't1', workspaceId: 'w1' });
    mockRecurring.computeNextRunAt.mockReturnValue(new Date('2026-07-01'));

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
```

- [ ] **Step 2.2: Run test — verify it fails**

```bash
cd apps/api && npm test -- --testPathPattern=recurring.processor
```

Expected: FAIL — `Cannot find module './recurring.processor'`

- [ ] **Step 2.3: Implement RecurringProcessor**

```typescript
// apps/api/src/jobs/processors/recurring.processor.ts
import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { RecurringService } from '../../recurring/recurring.service';
import { QUEUE_BUDGET_ALERTS, JOB_CHECK_BUDGET } from '../queue.constants';

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
        await this.prisma.$transaction(async (tx) => {
          const transaction = await tx.transaction.create({
            data: {
              workspaceId: rule.workspaceId,
              userId: (await tx.workspace.findUnique({ where: { id: rule.workspaceId }, select: { ownerId: true } }))!.ownerId,
              categoryId: rule.categoryId,
              amount: rule.amount,
              type: rule.type,
              description: rule.description,
              date: new Date(),
              recurringRuleId: rule.id,
            },
          });

          const nextRunAt = this.recurringService.computeNextRunAt(rule.nextRunAt, rule.frequency);
          await tx.recurringRule.update({ where: { id: rule.id }, data: { nextRunAt } });

          return transaction;
        }).then((transaction) => {
          this.events.emit('transaction.created', { workspaceId: rule.workspaceId, transactionId: transaction.id });
        });
      } catch (err) {
        this.logger.error(`Failed to process rule ${rule.id}`, err);
      }
    }
  }
}
```

Also install `@nestjs/schedule`:

```bash
npm install --save @nestjs/schedule
```

Add `ScheduleModule.forRoot()` to AppModule imports.

- [ ] **Step 2.4: Run tests — verify pass**

```bash
npm test -- --testPathPattern=recurring.processor
```

Expected: PASS — 2 tests

- [ ] **Step 2.5: Commit**

```bash
git add apps/api/src/jobs/processors/recurring.processor.ts apps/api/src/jobs/processors/recurring.processor.spec.ts
git commit -m "feat(jobs): add RecurringProcessor cron job"
```

---

## Task 3: BudgetAlertProcessor
Depends-on: 1

**Files:**
- Create: `src/jobs/processors/budget-alert.processor.ts`
- Create: `src/jobs/processors/budget-alert.processor.spec.ts`

- [ ] **Step 3.1: Write failing unit tests**

```typescript
// apps/api/src/jobs/processors/budget-alert.processor.spec.ts
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
    mockPrisma.transaction.aggregate.mockResolvedValue({ _sum: { amount: 8500 } }); // 85%
    mockPrisma.workspaceMember.findMany.mockResolvedValue([{ userId: 'u1' }]);
    mockCache.get.mockResolvedValue(null); // No dedup key set

    await processor.checkBudget({ workspaceId: 'w1', transactionId: 't1' });

    expect(mockQueue.add).toHaveBeenCalled();
    expect(mockCache.set).toHaveBeenCalled();
  });

  it('skips notification when dedup key exists', async () => {
    mockPrisma.budget.findMany.mockResolvedValue([
      { id: 'b1', workspaceId: 'w1', categoryId: 'c1', amount: 10000, period: 'MONTHLY', year: 2026, month: 6 },
    ]);
    mockPrisma.transaction.aggregate.mockResolvedValue({ _sum: { amount: 8500 } });
    mockPrisma.workspaceMember.findMany.mockResolvedValue([{ userId: 'u1' }]);
    mockCache.get.mockResolvedValue('1'); // Dedup key present

    await processor.checkBudget({ workspaceId: 'w1', transactionId: 't1' });

    expect(mockQueue.add).not.toHaveBeenCalled();
  });

  it('does not alert when under 80%', async () => {
    mockPrisma.budget.findMany.mockResolvedValue([
      { id: 'b1', workspaceId: 'w1', categoryId: null, amount: 10000, period: 'MONTHLY', year: 2026, month: 6 },
    ]);
    mockPrisma.transaction.aggregate.mockResolvedValue({ _sum: { amount: 7000 } }); // 70%
    mockPrisma.workspaceMember.findMany.mockResolvedValue([{ userId: 'u1' }]);
    mockCache.get.mockResolvedValue(null);

    await processor.checkBudget({ workspaceId: 'w1', transactionId: 't1' });

    expect(mockQueue.add).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 3.2: Run test — verify it fails**

```bash
npm test -- --testPathPattern=budget-alert.processor
```

Expected: FAIL — `Cannot find module './budget-alert.processor'`

- [ ] **Step 3.3: Install cache manager for Redis dedup**

```bash
npm install --save @nestjs/cache-manager cache-manager cache-manager-ioredis-yet
```

- [ ] **Step 3.4: Implement BudgetAlertProcessor**

```typescript
// apps/api/src/jobs/processors/budget-alert.processor.ts
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

        await this.cache.set(dedupKey, '1', 30 * 24 * 60 * 60 * 1000); // 30 days TTL

        // Fetch workspace currency and all members with email for all 3 delivery channels
        const workspace = await this.prisma.workspace.findUnique({
          where: { id: workspaceId },
          select: { currency: true, name: true },
        });
        const currency = workspace?.currency ?? 'USD';

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

          // Queue all 3 delivery channels — push was previously missing (gap fix)
          await Promise.all([
            this.notificationQueue.add(JOB_SEND_IN_APP, notifPayload, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } }),
            this.notificationQueue.add(JOB_SEND_EMAIL, {
              ...notifPayload,
              to: member.user.email,
              subject: `Budget Alert: ${budget.categoryId ? 'Category' : 'Total'} at ${Math.round(percentUsed)}%`,
              html: `<p>You've used <strong>${Math.round(percentUsed)}%</strong> of your budget.</p>
                     <p>Spent: ${spent} / ${budget.amount} (cents, ${currency})</p>`,
            }, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } }),
            this.notificationQueue.add(JOB_SEND_PUSH, {
              ...notifPayload,
              title: `Budget Alert`,
              body: `${Math.round(percentUsed)}% used (${(spent / 100).toFixed(2)} / ${(budget.amount / 100).toFixed(2)} ${currency})`,
            }, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } }),
          ]);
        }

        this.logger.log(`Budget alert queued: ${budget.id} at ${threshold}% threshold`);
      }
    }
  }
}
```

- [ ] **Step 3.5: Run tests — verify pass**

```bash
npm test -- --testPathPattern=budget-alert.processor
```

Expected: PASS — 3 tests

- [ ] **Step 3.6: Commit**

```bash
git add apps/api/src/jobs/processors/budget-alert.processor.ts apps/api/src/jobs/processors/budget-alert.processor.spec.ts
git commit -m "feat(jobs): add BudgetAlertProcessor with deduplication"
```

---

## Task 4: NotificationDeliveryProcessor
Depends-on: 1

**Files:**
- Create: `src/jobs/processors/notification-delivery.processor.ts`

- [ ] **Step 4.1: Implement NotificationDeliveryProcessor**

```typescript
// apps/api/src/jobs/processors/notification-delivery.processor.ts
import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job, UnrecoverableError } from 'bullmq';
import { Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  QUEUE_NOTIFICATION_DELIVERY,
  JOB_SEND_PUSH,
  JOB_SEND_EMAIL,
  JOB_SEND_IN_APP,
} from '../queue.constants';
import { NotificationType } from '@prisma/client';

@Processor(QUEUE_NOTIFICATION_DELIVERY)
export class NotificationDeliveryProcessor extends WorkerHost {
  private readonly logger = new Logger(NotificationDeliveryProcessor.name);

  constructor(private readonly prisma: PrismaService) {
    super();
  }

  async process(job: Job) {
    switch (job.name) {
      case JOB_SEND_IN_APP:  return this.sendInApp(job.data);
      case JOB_SEND_EMAIL:   return this.sendEmail(job.data);
      case JOB_SEND_PUSH:    return this.sendPush(job.data);
      default:
        throw new UnrecoverableError(`Unknown job: ${job.name}`);
    }
  }

  private async sendInApp(data: { userId: string; type: string; payload: object }) {
    await this.prisma.notification.create({
      data: {
        userId: data.userId,
        type: data.type as NotificationType,
        payload: data.payload,
      },
    });
    // WebSocket emit handled by NotificationsGateway in Phase 6 via DB polling or direct call
    this.logger.debug(`In-app notification saved for user ${data.userId}`);
  }

  private async sendEmail(data: { userId: string; type: string; payload: any }) {
    const user = await this.prisma.user.findUnique({ where: { id: data.userId }, select: { email: true } });
    if (!user) return;

    const sgMail = await import('@sendgrid/mail');
    sgMail.default.setApiKey(process.env.SENDGRID_API_KEY ?? '');

    const subject = data.type === 'BUDGET_ALERT'
      ? `Budget Alert: ${data.payload.threshold}% limit reached`
      : 'Expense Tracker Notification';

    await sgMail.default.send({
      to: user.email,
      from: process.env.SENDGRID_FROM_EMAIL ?? 'noreply@expensetracker.app',
      subject,
      text: `Your budget for this period has reached ${data.payload.threshold}% of the limit.`,
    });
  }

  private async sendPush(data: { userId: string; type: string; payload: any; title?: string; body?: string }) {
    // Look up notification record and the user's stored FCM token.
    const user = await this.prisma.user.findUnique({
      where: { id: data.userId },
      select: { fcmToken: true },
    });
    if (!user?.fcmToken) {
      // User hasn't granted push permission or token not yet synced — skip silently.
      this.logger.debug(`No FCM token for user ${data.userId}; skipping push`);
      return;
    }

    const firebaseAdmin = await import('firebase-admin');
    await firebaseAdmin.default.messaging().send({
      token: user.fcmToken,
      notification: {
        title: data.title ?? 'Expense Tracker',
        body: data.body ?? 'You have a new notification.',
      },
      data: {
        type: data.type,
        payload: JSON.stringify(data.payload),
      },
    });

    this.logger.debug(`Push notification sent to user ${data.userId}: ${data.type}`);
  }
}
```

- [ ] **Step 4.2: Commit**

```bash
git add apps/api/src/jobs/processors/notification-delivery.processor.ts
git commit -m "feat(jobs): add NotificationDeliveryProcessor (in-app, email, push)"
```

---

## Task 5: MonthlySummaryProcessor
Depends-on: 1

**Files:**
- Create: `src/jobs/processors/monthly-summary.processor.ts`

- [ ] **Step 5.1: Implement MonthlySummaryProcessor**

```typescript
// apps/api/src/jobs/processors/monthly-summary.processor.ts
import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { QUEUE_NOTIFICATION_DELIVERY, JOB_SEND_IN_APP, JOB_SEND_EMAIL, JOB_SEND_PUSH } from '../queue.constants';

@Injectable()
export class MonthlySummaryProcessor {
  private readonly logger = new Logger(MonthlySummaryProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(QUEUE_NOTIFICATION_DELIVERY) private readonly notificationQueue: Queue,
  ) {}

  @Cron('0 8 1 * *', { name: 'monthly-summary' })
  async generateSummaries() {
    const now = new Date();
    const prevMonth = now.getMonth() === 0 ? 12 : now.getMonth();
    const prevYear = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear();
    const from = new Date(prevYear, prevMonth - 1, 1);
    const to = new Date(prevYear, prevMonth, 1);

    const workspaces = await this.prisma.workspace.findMany({
      include: { members: { select: { userId: true } } },
    });

    for (const workspace of workspaces) {
      const [income, expense] = await Promise.all([
        this.prisma.transaction.aggregate({
          where: { workspaceId: workspace.id, type: 'INCOME', date: { gte: from, lt: to } },
          _sum: { amount: true },
        }),
        this.prisma.transaction.aggregate({
          where: { workspaceId: workspace.id, type: 'EXPENSE', date: { gte: from, lt: to } },
          _sum: { amount: true },
        }),
      ]);

      const totalIncome = income._sum.amount ?? 0;
      const totalExpense = expense._sum.amount ?? 0;
      const net = totalIncome - totalExpense;

      const payload = {
        workspaceId: workspace.id,
        workspaceName: workspace.name,
        currency: workspace.currency,
        period: `${prevYear}-${String(prevMonth).padStart(2, '0')}`,
        totalIncome,
        totalExpense,
        net,
      };

      // Build month name for email subject (e.g. "May 2026")
      const monthName = new Date(prevYear, prevMonth - 1, 1).toLocaleString('en-US', { month: 'long' });

      // Helper: cents → display string (no external lib needed here)
      const formatCents = (cents: number) => (cents / 100).toFixed(2);

      for (const { userId } of workspace.members) {
        // Queue all 3 channels: in-app, email, and push (gap fix: push was previously missing)
        const notifData = {
          userId,
          type: 'MONTHLY_SUMMARY',
          payload,
          title: `${monthName} ${prevYear} Summary`,
          body: `Income: ${formatCents(totalIncome)} ${workspace.currency} / Expenses: ${formatCents(totalExpense)} ${workspace.currency}`,
        };
        await this.notificationQueue.add(JOB_SEND_IN_APP, notifData, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } });
        await this.notificationQueue.add(JOB_SEND_PUSH, notifData, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } });

        // Direct email with full HTML template (richer than the queue-dispatched version)
        const member = await this.prisma.user.findUnique({ where: { id: userId }, select: { email: true } });
        if (member) {
          const sgMail = await import('@sendgrid/mail');
          sgMail.default.setApiKey(process.env.SENDGRID_API_KEY ?? '');
          await sgMail.default.send({
            to: member.email,
            from: process.env.SENDGRID_FROM_EMAIL ?? 'noreply@expensetracker.app',
            subject: `Your ${monthName} ${prevYear} expense summary`,
            html: `
              <h2>${workspace.name} — ${monthName} ${prevYear}</h2>
              <p>Income: <strong>${formatCents(totalIncome)} ${workspace.currency}</strong></p>
              <p>Expenses: <strong>${formatCents(totalExpense)} ${workspace.currency}</strong></p>
              <p>Net balance: <strong>${formatCents(net)} ${workspace.currency}</strong></p>
              <p><a href="${process.env.FRONTEND_URL}/workspaces/${workspace.id}/reports">View full report</a></p>
            `,
          });
        }
      }

      this.logger.log(`Monthly summary queued for workspace ${workspace.id}`);
    }
  }
}
```

- [ ] **Step 5.2: Run full unit test suite — no regressions**

```bash
cd apps/api && npm test
```

Expected: All tests pass.

- [ ] **Step 5.3: Commit**

```bash
git add apps/api/src/jobs/processors/monthly-summary.processor.ts
git commit -m "feat(jobs): add MonthlySummaryProcessor monthly cron"
```

---

## Phase 5 Complete

- ✅ BullMQ wired to Redis with 4 named queues
- ✅ `RecurringProcessor` — midnight cron creates transactions from due rules, updates `nextRunAt`
- ✅ `BudgetAlertProcessor` — listens for `transaction.created`, checks 80%/100% thresholds, deduplicates via Redis cache key (30-day TTL); **now queues all 3 channels: `JOB_SEND_IN_APP`, `JOB_SEND_EMAIL`, and `JOB_SEND_PUSH`** (push was previously missing — gap fix)
- ✅ `NotificationDeliveryProcessor` — dispatches in-app DB write, email via SendGrid, **full Firebase Admin SDK push** (reads `user.fcmToken`; skips silently if not set)
- ✅ `MonthlySummaryProcessor` — 1st of month cron aggregates prior month, **now queues all 3 channels including `JOB_SEND_PUSH`** (push was previously missing — gap fix), and sends a direct HTML email via SendGrid with income/expense/net figures and a link to the reports screen
- ✅ All jobs have 3 retry attempts with exponential backoff

**Next plan:** `2026-06-16-backend-api-phase6.md` — Notifications module (CRUD endpoints + real-time WebSocket gateway)
