# Backend API — Phase 7: Reports & Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `ReportsModule` with six analytics endpoints and two export endpoints (CSV + PDF). All aggregation queries use Prisma `$queryRaw` with tagged template literals for performance. Money values returned are always integers (cents) and converted to human-readable strings only at the UI layer.

**Architecture:** `ReportsModule` has a single service and controller. All routes are workspace-scoped and guarded by `WorkspaceMemberGuard`. Export endpoints stream the response using `StreamableFile`. No ORM queries — all report logic uses raw parameterized SQL.

**Critical convention:** Never use `$queryRawUnsafe` or string interpolation in SQL. All user inputs must be passed as parameters in the tagged template literal.

**Tech Stack:** `csv-writer` (CSV export), `pdfkit` (PDF export), `@types/pdfkit`

**Prerequisite:** Phase 6 complete. `WorkspaceMemberGuard`, `PrismaService`, `CurrentUser` decorator available.

---

## File Map

| File | Responsibility |
|---|---|
| `src/reports/reports.module.ts` | Module wiring |
| `src/reports/reports.service.ts` | All raw SQL aggregation methods + export stream generators |
| `src/reports/reports.service.spec.ts` | Unit tests for aggregation logic |
| `src/reports/reports.controller.ts` | 8 endpoints: 6 analytics + 2 export |
| `src/reports/dto/report-query.dto.ts` | Shared query params DTO |

---

## Task 1: ReportsModule setup + DTO

**Files:**
- Create: `src/reports/dto/report-query.dto.ts`
- Create: `src/reports/reports.module.ts`

- [ ] **Step 1.1: Create DTO**

```typescript
// apps/api/src/reports/dto/report-query.dto.ts
import { IsInt, IsOptional, Min, Max, IsString, Length } from 'class-validator';
import { Type } from 'class-transformer';

export class ReportQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(2020) @Max(2100)
  year?: number;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(12)
  month?: number;

  @IsOptional() @IsString() @Length(1, 50)
  categoryId?: string;
}
```

- [ ] **Step 1.2: Create ReportsModule (placeholder — service and controller added in later tasks)**

```typescript
// apps/api/src/reports/reports.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { WorkspacesModule } from '../workspaces/workspaces.module';
import { ReportsService } from './reports.service';
import { ReportsController } from './reports.controller';

@Module({
  imports: [PrismaModule, WorkspacesModule],
  providers: [ReportsService],
  controllers: [ReportsController],
})
export class ReportsModule {}
```

Add `ReportsModule` to `AppModule` imports.

- [ ] **Step 1.3: Commit**

```bash
git add apps/api/src/reports/
git commit -m "feat(reports): add ReportsModule scaffold and DTO"
```

---

## Task 2: ReportsService — analytics queries
Depends-on: 1

**Files:**
- Create: `src/reports/reports.service.ts`
- Create: `src/reports/reports.service.spec.ts`

- [ ] **Step 2.1: Write failing unit tests**

```typescript
// apps/api/src/reports/reports.service.spec.ts
import { Test } from '@nestjs/testing';
import { ReportsService } from './reports.service';
import { PrismaService } from '../prisma/prisma.service';

const mockPrisma = { $queryRaw: jest.fn() };

describe('ReportsService', () => {
  let service: ReportsService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        ReportsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();
    service = module.get(ReportsService);
  });

  describe('getSummary', () => {
    it('returns total income, expense, and net for a period', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        { type: 'INCOME', total: BigInt(100000) },
        { type: 'EXPENSE', total: BigInt(75000) },
      ]);
      const result = await service.getSummary('w1', 2026, 6);
      expect(result.totalIncome).toBe(100000);
      expect(result.totalExpense).toBe(75000);
      expect(result.net).toBe(25000);
    });

    it('handles empty month (all zeros)', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([]);
      const result = await service.getSummary('w1', 2026, 6);
      expect(result.totalIncome).toBe(0);
      expect(result.totalExpense).toBe(0);
      expect(result.net).toBe(0);
    });
  });

  describe('getByCategory', () => {
    it('returns spending grouped by category', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        { categoryId: 'c1', categoryName: 'Food', total: BigInt(30000), count: BigInt(5) },
      ]);
      const result = await service.getByCategory('w1', 2026, 6);
      expect(result[0].total).toBe(30000);
      expect(result[0].count).toBe(5);
    });
  });

  describe('getTrends', () => {
    it('returns monthly totals for the given year', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        { month: 1, type: 'INCOME', total: BigInt(50000) },
        { month: 1, type: 'EXPENSE', total: BigInt(40000) },
      ]);
      const result = await service.getTrends('w1', 2026);
      expect(result).toHaveLength(1);
    });
  });

  describe('getBudgetVsActual', () => {
    it('returns budget vs actual spend per category', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        { budgetId: 'b1', categoryId: 'c1', categoryName: 'Housing', budgetAmount: BigInt(120000), actualAmount: BigInt(90000) },
      ]);
      const result = await service.getBudgetVsActual('w1', 2026, 6);
      expect(result[0].budgetAmount).toBe(120000);
      expect(result[0].actualAmount).toBe(90000);
    });
  });
});
```

- [ ] **Step 2.2: Run test — verify it fails**

```bash
cd apps/api && npm test -- --testPathPattern=reports.service
```

Expected: FAIL — `Cannot find module './reports.service'`

- [ ] **Step 2.3: Implement ReportsService**

```typescript
// apps/api/src/reports/reports.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Readable } from 'stream';

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async getSummary(workspaceId: string, year: number, month: number) {
    const rows = await this.prisma.$queryRaw<{ type: string; total: bigint }[]>`
      SELECT type, SUM(amount) AS total
      FROM transactions
      WHERE workspace_id = ${workspaceId}
        AND EXTRACT(YEAR FROM date) = ${year}
        AND EXTRACT(MONTH FROM date) = ${month}
      GROUP BY type
    `;

    const income = rows.find((r) => r.type === 'INCOME');
    const expense = rows.find((r) => r.type === 'EXPENSE');
    const totalIncome = Number(income?.total ?? 0);
    const totalExpense = Number(expense?.total ?? 0);

    return { totalIncome, totalExpense, net: totalIncome - totalExpense, year, month };
  }

  async getByCategory(workspaceId: string, year: number, month: number) {
    const rows = await this.prisma.$queryRaw<{ categoryId: string; categoryName: string; total: bigint; count: bigint }[]>`
      SELECT t.category_id AS "categoryId",
             c.name AS "categoryName",
             SUM(t.amount) AS total,
             COUNT(t.id) AS count
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.workspace_id = ${workspaceId}
        AND t.type = 'EXPENSE'
        AND EXTRACT(YEAR FROM t.date) = ${year}
        AND EXTRACT(MONTH FROM t.date) = ${month}
      GROUP BY t.category_id, c.name
      ORDER BY total DESC
    `;

    return rows.map((r) => ({ ...r, total: Number(r.total), count: Number(r.count) }));
  }

  async getTrends(workspaceId: string, year: number) {
    const rows = await this.prisma.$queryRaw<{ month: number; type: string; total: bigint }[]>`
      SELECT EXTRACT(MONTH FROM date)::int AS month,
             type,
             SUM(amount) AS total
      FROM transactions
      WHERE workspace_id = ${workspaceId}
        AND EXTRACT(YEAR FROM date) = ${year}
      GROUP BY month, type
      ORDER BY month ASC
    `;

    return rows.map((r) => ({ ...r, total: Number(r.total) }));
  }

  async getBudgetVsActual(workspaceId: string, year: number, month: number) {
    const rows = await this.prisma.$queryRaw<{
      budgetId: string; categoryId: string | null; categoryName: string | null;
      budgetAmount: bigint; actualAmount: bigint;
    }[]>`
      SELECT b.id AS "budgetId",
             b.category_id AS "categoryId",
             c.name AS "categoryName",
             b.amount AS "budgetAmount",
             COALESCE(SUM(t.amount), 0) AS "actualAmount"
      FROM budgets b
      LEFT JOIN categories c ON c.id = b.category_id
      LEFT JOIN transactions t
        ON t.workspace_id = b.workspace_id
        AND (b.category_id IS NULL OR t.category_id = b.category_id)
        AND t.type = 'EXPENSE'
        AND EXTRACT(YEAR FROM t.date) = ${year}
        AND EXTRACT(MONTH FROM t.date) = ${month}
      WHERE b.workspace_id = ${workspaceId}
        AND b.period = 'MONTHLY'
        AND b.year = ${year}
        AND b.month = ${month}
      GROUP BY b.id, b.category_id, c.name, b.amount
    `;

    return rows.map((r) => ({
      ...r,
      budgetAmount: Number(r.budgetAmount),
      actualAmount: Number(r.actualAmount),
    }));
  }

  async getYearOverYear(workspaceId: string) {
    const rows = await this.prisma.$queryRaw<{ year: number; month: number; type: string; total: bigint }[]>`
      SELECT EXTRACT(YEAR FROM date)::int AS year,
             EXTRACT(MONTH FROM date)::int AS month,
             type,
             SUM(amount) AS total
      FROM transactions
      WHERE workspace_id = ${workspaceId}
        AND date >= NOW() - INTERVAL '2 years'
      GROUP BY year, month, type
      ORDER BY year ASC, month ASC
    `;

    return rows.map((r) => ({ ...r, total: Number(r.total) }));
  }

  async getHeatmap(workspaceId: string, year: number) {
    const rows = await this.prisma.$queryRaw<{ day: string; total: bigint }[]>`
      SELECT TO_CHAR(date, 'YYYY-MM-DD') AS day,
             SUM(amount) AS total
      FROM transactions
      WHERE workspace_id = ${workspaceId}
        AND type = 'EXPENSE'
        AND EXTRACT(YEAR FROM date) = ${year}
      GROUP BY day
      ORDER BY day ASC
    `;

    return rows.map((r) => ({ day: r.day, total: Number(r.total) }));
  }

  async exportCsv(workspaceId: string, year: number, month: number): Promise<Buffer> {
    // Get workspace currency for the Amount display column
    const workspace = await this.prisma.workspace.findUniqueOrThrow({
      where: { id: workspaceId },
      select: { currency: true },
    });

    const rows = await this.prisma.$queryRaw<{
      date: Date; type: string; categoryName: string; amount: bigint; description: string | null;
    }[]>`
      SELECT t.date,
             t.type,
             c.name AS "categoryName",
             t.amount,
             t.description
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.workspace_id = ${workspaceId}
        AND EXTRACT(YEAR FROM t.date) = ${year}
        AND EXTRACT(MONTH FROM t.date) = ${month}
      ORDER BY t.date ASC
    `;

    // UTF-8 BOM for Excel compatibility
    const BOM = '﻿';
    const csvRows = rows.map((r) => ({
      Date: r.date.toISOString().split('T')[0],
      Type: r.type,
      Category: r.categoryName,
      Description: r.description ?? '',
      Amount: (Number(r.amount) / 100).toFixed(2), // display as decimal, not cents
      Currency: workspace.currency,
    }));

    const header = Object.keys(csvRows[0] ?? { Date: '', Type: '', Category: '', Description: '', Amount: '', Currency: '' }).join(',');
    const body = csvRows
      .map((r) => Object.values(r).map((v) => `"${String(v).replace(/"/g, '""')}"`).join(','))
      .join('\n');

    return Buffer.from(BOM + header + '\n' + body, 'utf-8');
    // Controller must set:
    // res.setHeader('Content-Type', 'text/csv; charset=utf-8')
    // res.setHeader('Content-Disposition', `attachment; filename="transactions-${year}-${String(month).padStart(2,'0')}.csv"`)
    // res.end(buffer)
  }

  async exportPdf(workspaceId: string, year: number, month: number): Promise<Readable> {
    const PDFDocument = (await import('pdfkit')).default;
    const { format } = await import('date-fns');

    const workspace = await this.prisma.workspace.findUniqueOrThrow({
      where: { id: workspaceId },
      select: { name: true, currency: true },
    });

    const summary = await this.getSummary(workspaceId, year, month);
    const byCategory = await this.getByCategory(workspaceId, year, month);
    const transactions = await this.prisma.transaction.findMany({
      where: { workspaceId, date: {
        gte: new Date(year, month - 1, 1),
        lt: new Date(year, month, 1),
      }},
      include: { category: true },
      orderBy: { date: 'asc' },
    });

    const totalIncome = summary.totalIncome;
    const totalExpenses = summary.totalExpense;
    const netBalance = summary.net;

    const doc = new PDFDocument({ margin: 50 });
    const readable = new Readable({ read() {} });

    doc.on('data', (chunk: Buffer) => readable.push(chunk));
    doc.on('end', () => readable.push(null));

    const periodLabel = format(new Date(year, month - 1, 1), 'MMMM yyyy');
    const fromLabel = format(new Date(year, month - 1, 1), 'MMM d, yyyy');
    const toLabel = format(new Date(year, month, 0), 'MMM d, yyyy'); // last day of month

    // Header with workspace branding
    doc.fontSize(18).font('Helvetica-Bold').text(`${workspace.name} — Transaction Report`, { align: 'center' });
    doc.fontSize(12).font('Helvetica').text(`Period: ${fromLabel} – ${toLabel}`, { align: 'center' });
    doc.text(`Currency: ${workspace.currency}`, { align: 'center' });
    doc.moveDown();

    // Transaction table
    doc.font('Helvetica-Bold').text('Date        Type       Category             Amount');
    doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
    doc.font('Helvetica');
    for (const t of transactions) {
      doc.text(
        `${format(t.date, 'yyyy-MM-dd')}  ${t.type.padEnd(9)}  ${t.category.name.substring(0, 20).padEnd(20)}  ${(t.amount / 100).toFixed(2)} ${workspace.currency}`
      );
    }

    // Totals
    doc.moveDown().font('Helvetica-Bold');
    doc.text(`Total Income:   ${(totalIncome / 100).toFixed(2)} ${workspace.currency}`);
    doc.text(`Total Expenses: ${(totalExpenses / 100).toFixed(2)} ${workspace.currency}`);
    doc.text(`Net Balance:    ${(netBalance / 100).toFixed(2)} ${workspace.currency}`);

    doc.end();
    return readable;
  }
}
```

- [ ] **Step 2.4: Run tests — verify pass**

```bash
npm test -- --testPathPattern=reports.service
```

Expected: PASS — 5 tests

- [ ] **Step 2.5: Commit**

```bash
git add apps/api/src/reports/reports.service.ts apps/api/src/reports/reports.service.spec.ts
git commit -m "feat(reports): add ReportsService with raw SQL aggregations"
```

---

## Task 3: ReportsController
Depends-on: 2

**Files:**
- Create: `src/reports/reports.controller.ts`

- [ ] **Step 3.1: Install export packages**

```bash
cd apps/api
npm install --save pdfkit
npm install --save-dev @types/pdfkit
```

- [ ] **Step 3.2: Implement ReportsController**

```typescript
// apps/api/src/reports/reports.controller.ts
import { Controller, Get, Param, Query, UseGuards, Res, Header } from '@nestjs/common';
import { Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../workspaces/guards/workspace-member.guard';
import { ReportsService } from './reports.service';
import { ReportQueryDto } from './dto/report-query.dto';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/reports')
export class ReportsController {
  constructor(private readonly service: ReportsService) {}

  private parseYearMonth(query: ReportQueryDto) {
    const now = new Date();
    return {
      year: query.year ?? now.getFullYear(),
      month: query.month ?? (now.getMonth() + 1),
    };
  }

  @Get('summary')
  async getSummary(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const { year, month } = this.parseYearMonth(query);
    return this.service.getSummary(wid, year, month);
  }

  @Get('by-category')
  async getByCategory(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const { year, month } = this.parseYearMonth(query);
    return this.service.getByCategory(wid, year, month);
  }

  @Get('trends')
  async getTrends(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const year = query.year ?? new Date().getFullYear();
    return this.service.getTrends(wid, year);
  }

  @Get('budget-vs-actual')
  async getBudgetVsActual(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const { year, month } = this.parseYearMonth(query);
    return this.service.getBudgetVsActual(wid, year, month);
  }

  @Get('year-over-year')
  async getYearOverYear(@Param('workspaceId') wid: string) {
    return this.service.getYearOverYear(wid);
  }

  @Get('heatmap')
  async getHeatmap(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const year = query.year ?? new Date().getFullYear();
    return this.service.getHeatmap(wid, year);
  }

  @Get('export/csv')
  async exportCsv(
    @Param('workspaceId') wid: string,
    @Query() query: ReportQueryDto,
    @Res() res: Response,
  ) {
    const { year, month } = this.parseYearMonth(query);
    const buffer = await this.service.exportCsv(wid, year, month);
    const monthStr = String(month).padStart(2, '0');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="transactions-${year}-${monthStr}.csv"`);
    res.end(buffer);
  }

  @Get('export/pdf')
  @Header('Content-Type', 'application/pdf')
  async exportPdf(
    @Param('workspaceId') wid: string,
    @Query() query: ReportQueryDto,
    @Res() res: Response,
  ) {
    const { year, month } = this.parseYearMonth(query);
    const stream = await this.service.exportPdf(wid, year, month);
    res.setHeader('Content-Disposition', `attachment; filename="report-${year}-${month}.pdf"`);
    stream.pipe(res);
  }
}
```

- [ ] **Step 3.3: Run full unit test suite — no regressions**

```bash
cd apps/api && npm test
```

Expected: All tests pass.

- [ ] **Step 3.4: Commit**

```bash
git add apps/api/src/reports/reports.controller.ts
git commit -m "feat(reports): add ReportsController with analytics and export endpoints"
```

---

## Task 4: Integration smoke test (manual)
Depends-on: 3

**Requires:** `docker compose up -d` and running API

- [ ] **Step 4.1: Manual API validation**

```bash
# Start API
cd apps/api && npm run start:dev

# Login and capture token
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Password1!"}' \
  | jq -r '.data.accessToken')

# Create a workspace and get its ID
WORKSPACE_ID="<id from workspace creation>"

# Test summary
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/workspaces/$WORKSPACE_ID/reports/summary?year=2026&month=6"

# Test CSV export
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/workspaces/$WORKSPACE_ID/reports/export/csv?year=2026&month=6" \
  -o report.csv

# Test PDF export
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/workspaces/$WORKSPACE_ID/reports/export/pdf?year=2026&month=6" \
  -o report.pdf
```

Expected: Summary returns JSON, CSV downloads file, PDF downloads binary.

---

## Phase 7 Complete

- ✅ `ReportsService` — 6 analytics methods using `$queryRaw` parameterized SQL (never `$queryRawUnsafe`)
  - `getSummary` — total income/expense/net for a month
  - `getByCategory` — expense breakdown by category
  - `getTrends` — monthly income/expense for a year
  - `getBudgetVsActual` — budget vs actual spend per budget
  - `getYearOverYear` — rolling 2-year monthly comparison
  - `getHeatmap` — daily expense totals for heatmap visualization
- ✅ **CSV export** — returns `Buffer` with UTF-8 BOM (Excel-compatible), amounts displayed as decimal (not raw cents), all fields double-quote escaped, `Content-Type: text/csv; charset=utf-8`
- ✅ **PDF export** — workspace-branded header (name, period, currency), transaction table with date/type/category/amount columns, totals footer (income/expenses/net), amounts displayed as decimal with currency code
- ✅ `ReportsController` — all routes under `workspaces/:workspaceId/reports`, protected by `WorkspaceMemberGuard`; CSV export uses `res.end(buffer)` with correct charset header
- ✅ Money values returned as integers (cents) in analytics endpoints; converted to decimal only in export outputs

**Next plan:** `2026-06-16-backend-api-phase8.md` — Docker + CI/CD + Deployment
