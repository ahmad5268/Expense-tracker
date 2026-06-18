# Backend API — Phase 4: Budgets & Recurring Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Budgets module (monthly/yearly budget limits per category or workspace-total) and the RecurringRules module (rules that auto-generate transactions on a schedule). Both are workspace-scoped and protected by WorkspaceMemberGuard.

**Architecture:** Budget uniqueness is enforced by a DB unique constraint on `(workspaceId, categoryId, period, year, month)`. RecurringRules store `nextRunAt` which the background job (Phase 5) uses to find due rules. Both modules emit no events — they are pure CRUD. The recurring rule `nextRunAt` is computed from `startDate` and `frequency` on create.

**Tech Stack:** NestJS, Prisma, class-validator, date-fns, Jest

**Prerequisite:** Phase 3 complete — `WorkspaceMemberGuard`, `WorkspacesModule`, `TransactionsModule` all in place.

---

## File Map

| File | Responsibility |
|---|---|
| `src/budgets/dto/create-budget.dto.ts` | Validated create body |
| `src/budgets/dto/update-budget.dto.ts` | Validated update body |
| `src/budgets/budgets.service.ts` | Budget CRUD logic |
| `src/budgets/budgets.service.spec.ts` | Unit tests |
| `src/budgets/budgets.controller.ts` | HTTP surface |
| `src/budgets/budgets.module.ts` | Module registration |
| `src/recurring/dto/create-recurring-rule.dto.ts` | Validated create body |
| `src/recurring/dto/update-recurring-rule.dto.ts` | Validated update body |
| `src/recurring/recurring.service.ts` | Recurring rule CRUD + nextRunAt computation |
| `src/recurring/recurring.service.spec.ts` | Unit tests |
| `src/recurring/recurring.controller.ts` | HTTP surface |
| `src/recurring/recurring.module.ts` | Module registration |

---

## Task 1: BudgetsModule

**Files:**
- Create: `src/budgets/dto/create-budget.dto.ts`
- Create: `src/budgets/dto/update-budget.dto.ts`
- Create: `src/budgets/budgets.service.ts`
- Create: `src/budgets/budgets.service.spec.ts`
- Create: `src/budgets/budgets.controller.ts`
- Create: `src/budgets/budgets.module.ts`

- [ ] **Step 1.1: Create Budget DTOs**

```typescript
// apps/api/src/budgets/dto/create-budget.dto.ts
import { IsInt, IsPositive, IsEnum, IsOptional, IsString, IsNumber, Min, Max } from 'class-validator';
import { BudgetPeriod } from '@prisma/client';

export class CreateBudgetDto {
  @IsOptional()
  @IsString()
  categoryId?: string; // null = workspace total budget

  @IsInt()
  @IsPositive()
  amount: number; // cents

  @IsEnum(BudgetPeriod)
  period: BudgetPeriod;

  @IsNumber()
  @Min(2020)
  @Max(2100)
  year: number;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(12)
  month?: number; // required for MONTHLY period
}
```

```typescript
// apps/api/src/budgets/dto/update-budget.dto.ts
import { IsInt, IsPositive, IsOptional } from 'class-validator';

export class UpdateBudgetDto {
  @IsOptional()
  @IsInt()
  @IsPositive()
  amount?: number;
}
```

- [ ] **Step 1.2: Write failing unit tests for BudgetsService**

```typescript
// apps/api/src/budgets/budgets.service.spec.ts
import { Test } from '@nestjs/testing';
import { BudgetsService } from './budgets.service';
import { PrismaService } from '../prisma/prisma.service';
import { BadRequestException } from '@nestjs/common';

const mockPrisma = {
  budget: { findMany: jest.fn(), create: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
};

describe('BudgetsService', () => {
  let service: BudgetsService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [BudgetsService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get(BudgetsService);
  });

  it('throws BadRequestException when MONTHLY budget has no month', async () => {
    await expect(
      service.create('w1', { amount: 100000, period: 'MONTHLY', year: 2026 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('throws BadRequestException when YEARLY budget has month set', async () => {
    await expect(
      service.create('w1', { amount: 1000000, period: 'YEARLY', year: 2026, month: 6 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('throws BadRequestException when month is 0 (below range)', async () => {
    await expect(
      service.create('w1', { amount: 100000, period: 'MONTHLY', year: 2026, month: 0 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('throws BadRequestException when month is 13 (above range)', async () => {
    await expect(
      service.create('w1', { amount: 100000, period: 'MONTHLY', year: 2026, month: 13 }),
    ).rejects.toThrow(BadRequestException);
  });

  it('creates YEARLY budget without month', async () => {
    mockPrisma.budget.create.mockResolvedValue({ id: 'b1', amount: 1000000 });
    const result = await service.create('w1', { amount: 1000000, period: 'YEARLY', year: 2026 });
    expect(result.id).toBe('b1');
  });

  it('findAll returns budgets for workspace', async () => {
    mockPrisma.budget.findMany.mockResolvedValue([{ id: 'b1' }]);
    const result = await service.findAll('w1');
    expect(result).toHaveLength(1);
  });

  it('workspace can have both total (categoryId=null) and category-specific budgets in same month', async () => {
    // Both a null-category total budget and a category-specific budget are valid simultaneously.
    // The DB unique constraint is per (workspaceId, categoryId, period, year, month), not per month alone.
    mockPrisma.budget.create.mockResolvedValueOnce({ id: 'b-total', categoryId: null, amount: 500000 });
    mockPrisma.budget.create.mockResolvedValueOnce({ id: 'b-food', categoryId: 'c1', amount: 100000 });

    const total = await service.create('w1', { amount: 500000, period: 'MONTHLY', year: 2026, month: 6 });
    const food = await service.create('w1', { amount: 100000, period: 'MONTHLY', year: 2026, month: 6, categoryId: 'c1' });

    expect(total.id).toBe('b-total');
    expect(food.id).toBe('b-food');
  });
});
```

- [ ] **Step 1.3: Run test — verify it fails**

```bash
cd apps/api && npm test -- --testPathPattern=budgets.service
```

Expected: FAIL — `Cannot find module './budgets.service'`

- [ ] **Step 1.4: Implement BudgetsService**

```typescript
// apps/api/src/budgets/budgets.service.ts
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
    // Design decision: workspace-total budget (categoryId = null) and category-level budgets
    // CAN coexist in the same period — they are NOT mutually exclusive.
    // The UI displays each independently in the budget-vs-actual report.
    // The DB unique constraint is on (workspaceId, categoryId, period, year, month)
    // which prevents duplicate budgets per category per period,
    // but allows both a null-category (total) budget AND category budgets simultaneously.

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
```

- [ ] **Step 1.5: Implement BudgetsController**

```typescript
// apps/api/src/budgets/budgets.controller.ts
import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { BudgetsService } from './budgets.service';
import { CreateBudgetDto } from './dto/create-budget.dto';
import { UpdateBudgetDto } from './dto/update-budget.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../workspaces/guards/workspace-member.guard';

@Controller('workspaces/:workspaceId/budgets')
@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
export class BudgetsController {
  constructor(private readonly budgetsService: BudgetsService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.budgetsService.findAll(workspaceId);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateBudgetDto) {
    return this.budgetsService.create(workspaceId, dto);
  }

  @Put(':budgetId')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('budgetId') budgetId: string,
    @Body() dto: UpdateBudgetDto,
  ) {
    return this.budgetsService.update(workspaceId, budgetId, dto);
  }

  @Delete(':budgetId')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param('workspaceId') workspaceId: string, @Param('budgetId') budgetId: string) {
    return this.budgetsService.remove(workspaceId, budgetId);
  }
}
```

- [ ] **Step 1.6: Implement BudgetsModule and register in AppModule**

```typescript
// apps/api/src/budgets/budgets.module.ts
import { Module } from '@nestjs/common';
import { BudgetsService } from './budgets.service';
import { BudgetsController } from './budgets.controller';
import { WorkspacesModule } from '../workspaces/workspaces.module';

@Module({
  imports: [WorkspacesModule],
  controllers: [BudgetsController],
  providers: [BudgetsService],
  exports: [BudgetsService],
})
export class BudgetsModule {}
```

Add `BudgetsModule` to AppModule imports.

- [ ] **Step 1.7: Run tests — verify pass**

```bash
npm test -- --testPathPattern=budgets.service
```

Expected: PASS — 3 tests

- [ ] **Step 1.8: Commit**

```bash
git add apps/api/src/budgets/ apps/api/src/app.module.ts
git commit -m "feat(budgets): add BudgetsModule with CRUD"
```

---

## Task 2: RecurringRulesModule
Depends-on: 1

**Files:**
- Create: `src/recurring/dto/create-recurring-rule.dto.ts`
- Create: `src/recurring/dto/update-recurring-rule.dto.ts`
- Create: `src/recurring/recurring.service.ts`
- Create: `src/recurring/recurring.service.spec.ts`
- Create: `src/recurring/recurring.controller.ts`
- Create: `src/recurring/recurring.module.ts`

- [ ] **Step 2.1: Create RecurringRule DTOs**

```typescript
// apps/api/src/recurring/dto/create-recurring-rule.dto.ts
import { IsString, IsInt, IsPositive, IsEnum, IsDateString, IsOptional, MaxLength } from 'class-validator';
import { TransactionType, Frequency } from '@prisma/client';

export class CreateRecurringRuleDto {
  @IsString()
  categoryId: string;

  @IsInt()
  @IsPositive()
  amount: number; // cents

  @IsEnum(TransactionType)
  type: TransactionType;

  @IsEnum(Frequency)
  frequency: Frequency;

  @IsDateString()
  startDate: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;
}
```

```typescript
// apps/api/src/recurring/dto/update-recurring-rule.dto.ts
import { IsInt, IsPositive, IsDateString, IsString, IsOptional, MaxLength, IsBoolean } from 'class-validator';

export class UpdateRecurringRuleDto {
  @IsOptional()
  @IsInt()
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
```

- [ ] **Step 2.2: Write failing unit tests for RecurringService**

```typescript
// apps/api/src/recurring/recurring.service.spec.ts
import { Test } from '@nestjs/testing';
import { RecurringService } from './recurring.service';
import { PrismaService } from '../prisma/prisma.service';

const mockPrisma = {
  recurringRule: { findMany: jest.fn(), create: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
};

describe('RecurringService', () => {
  let service: RecurringService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [RecurringService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get(RecurringService);
  });

  describe('computeNextRunAt', () => {
    it('returns startDate when it is in the future', () => {
      const future = new Date(Date.now() + 86400000);
      const result = service.computeNextRunAt(future, 'MONTHLY');
      expect(result).toEqual(future);
    });

    it('advances past date by one period for MONTHLY', () => {
      const past = new Date('2026-01-01');
      const result = service.computeNextRunAt(past, 'MONTHLY');
      expect(result > new Date()).toBe(true);
    });

    it('advances past date by one period for YEARLY', () => {
      const past = new Date('2025-01-01');
      const result = service.computeNextRunAt(past, 'YEARLY');
      expect(result.getFullYear()).toBeGreaterThanOrEqual(2026);
    });
  });

  it('findAll returns rules for workspace', async () => {
    mockPrisma.recurringRule.findMany.mockResolvedValue([{ id: 'r1' }]);
    const result = await service.findAll('w1');
    expect(result).toHaveLength(1);
  });
});
```

- [ ] **Step 2.3: Run test — verify it fails**

```bash
npm test -- --testPathPattern=recurring.service
```

Expected: FAIL — `Cannot find module './recurring.service'`

- [ ] **Step 2.4: Implement RecurringService**

```typescript
// apps/api/src/recurring/recurring.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateRecurringRuleDto } from './dto/create-recurring-rule.dto';
import { UpdateRecurringRuleDto } from './dto/update-recurring-rule.dto';
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
```

- [ ] **Step 2.5: Implement RecurringController**

```typescript
// apps/api/src/recurring/recurring.controller.ts
import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { RecurringService } from './recurring.service';
import { CreateRecurringRuleDto } from './dto/create-recurring-rule.dto';
import { UpdateRecurringRuleDto } from './dto/update-recurring-rule.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../workspaces/guards/workspace-member.guard';

@Controller('workspaces/:workspaceId/recurring')
@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
export class RecurringController {
  constructor(private readonly recurringService: RecurringService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.recurringService.findAll(workspaceId);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateRecurringRuleDto) {
    return this.recurringService.create(workspaceId, dto);
  }

  @Put(':ruleId')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('ruleId') ruleId: string,
    @Body() dto: UpdateRecurringRuleDto,
  ) {
    return this.recurringService.update(workspaceId, ruleId, dto);
  }

  @Delete(':ruleId')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param('workspaceId') workspaceId: string, @Param('ruleId') ruleId: string) {
    return this.recurringService.remove(workspaceId, ruleId);
  }
}
```

- [ ] **Step 2.6: Implement RecurringModule and register in AppModule**

```typescript
// apps/api/src/recurring/recurring.module.ts
import { Module } from '@nestjs/common';
import { RecurringService } from './recurring.service';
import { RecurringController } from './recurring.controller';
import { WorkspacesModule } from '../workspaces/workspaces.module';

@Module({
  imports: [WorkspacesModule],
  controllers: [RecurringController],
  providers: [RecurringService],
  exports: [RecurringService],
})
export class RecurringModule {}
```

Add `RecurringModule` to AppModule imports.

- [ ] **Step 2.7: Run tests — verify pass**

```bash
npm test -- --testPathPattern=recurring.service
```

Expected: PASS — 4 tests

- [ ] **Step 2.8: Run full test suite**

```bash
npm test
```

Expected: All tests pass.

- [ ] **Step 2.9: Commit**

```bash
git add apps/api/src/recurring/ apps/api/src/app.module.ts
git commit -m "feat(recurring): add RecurringModule with CRUD and nextRunAt computation"
```

---

## Phase 4 Complete

- ✅ Budget CRUD with monthly/yearly periods and category-level or workspace-total budgets
- ✅ Unique budget constraint enforced (DB + validation)
- ✅ **Budget coexistence policy documented:** workspace-total budget (`categoryId=null`) and category-specific budgets CAN coexist in the same period — they are additive, not mutually exclusive
- ✅ **Month validation:** MONTHLY requires `month` (1–12); YEARLY must NOT have `month`; out-of-range month → 400
- ✅ 7 unit tests for BudgetsService (including coexistence and boundary validation cases)
- ✅ Recurring rule CRUD with `nextRunAt` auto-computed from startDate + frequency
- ✅ `computeNextRunAt` unit tested for all four frequency types
- ✅ Both modules protected by `WorkspaceMemberGuard`

**Next plan:** `2026-06-16-backend-api-phase5.md` — Background Jobs (BullMQ: recurring transactions, budget alerts, notification delivery, monthly summary)
