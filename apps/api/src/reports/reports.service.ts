import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Readable } from 'stream';
// eslint-disable-next-line @typescript-eslint/no-require-imports
const PDFDocument = require('pdfkit') as typeof import('pdfkit');
import { format } from 'date-fns';

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async getSummary(workspaceId: string, year: number, month: number) {
    const rows = await this.prisma.$queryRaw<{ type: string; total: bigint }[]>`
      SELECT type, SUM(amount) AS total
      FROM "Transaction"
      WHERE "workspaceId" = ${workspaceId}
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
    const rows = await this.prisma.$queryRaw<{
      categoryId: string;
      categoryName: string;
      total: bigint;
      count: bigint;
    }[]>`
      SELECT t."categoryId",
             c.name AS "categoryName",
             SUM(t.amount) AS total,
             COUNT(t.id) AS count
      FROM "Transaction" t
      JOIN "Category" c ON c.id = t."categoryId"
      WHERE t."workspaceId" = ${workspaceId}
        AND t.type = 'EXPENSE'
        AND EXTRACT(YEAR FROM t.date) = ${year}
        AND EXTRACT(MONTH FROM t.date) = ${month}
      GROUP BY t."categoryId", c.name
      ORDER BY total DESC
    `;

    return rows.map((r) => ({ ...r, total: Number(r.total), count: Number(r.count) }));
  }

  async getTrends(workspaceId: string, year: number) {
    const rows = await this.prisma.$queryRaw<{ month: number; type: string; total: bigint }[]>`
      SELECT EXTRACT(MONTH FROM date)::int AS month,
             type,
             SUM(amount) AS total
      FROM "Transaction"
      WHERE "workspaceId" = ${workspaceId}
        AND EXTRACT(YEAR FROM date) = ${year}
      GROUP BY month, type
      ORDER BY month ASC
    `;

    return rows.map((r) => ({ ...r, total: Number(r.total) }));
  }

  async getBudgetVsActual(workspaceId: string, year: number, month: number) {
    const rows = await this.prisma.$queryRaw<{
      budgetId: string;
      categoryId: string | null;
      categoryName: string | null;
      budgetAmount: bigint;
      actualAmount: bigint;
    }[]>`
      SELECT b.id AS "budgetId",
             b."categoryId",
             c.name AS "categoryName",
             b.amount AS "budgetAmount",
             COALESCE(SUM(t.amount), 0) AS "actualAmount"
      FROM "Budget" b
      LEFT JOIN "Category" c ON c.id = b."categoryId"
      LEFT JOIN "Transaction" t
        ON t."workspaceId" = b."workspaceId"
        AND (b."categoryId" IS NULL OR t."categoryId" = b."categoryId")
        AND t.type = 'EXPENSE'
        AND EXTRACT(YEAR FROM t.date) = ${year}
        AND EXTRACT(MONTH FROM t.date) = ${month}
      WHERE b."workspaceId" = ${workspaceId}
        AND b.period = 'MONTHLY'
        AND b.year = ${year}
        AND b.month = ${month}
      GROUP BY b.id, b."categoryId", c.name, b.amount
    `;

    return rows.map((r) => ({
      ...r,
      budgetAmount: Number(r.budgetAmount),
      actualAmount: Number(r.actualAmount),
    }));
  }

  async getYearOverYear(workspaceId: string) {
    const rows = await this.prisma.$queryRaw<{
      year: number;
      month: number;
      type: string;
      total: bigint;
    }[]>`
      SELECT EXTRACT(YEAR FROM date)::int AS year,
             EXTRACT(MONTH FROM date)::int AS month,
             type,
             SUM(amount) AS total
      FROM "Transaction"
      WHERE "workspaceId" = ${workspaceId}
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
      FROM "Transaction"
      WHERE "workspaceId" = ${workspaceId}
        AND type = 'EXPENSE'
        AND EXTRACT(YEAR FROM date) = ${year}
      GROUP BY TO_CHAR(date, 'YYYY-MM-DD')
      ORDER BY day ASC
    `;

    return rows.map((r) => ({ day: r.day, total: Number(r.total) }));
  }

  async exportCsv(workspaceId: string, year: number, month: number): Promise<Buffer> {
    const workspace = await this.prisma.workspace.findUniqueOrThrow({
      where: { id: workspaceId },
      select: { currency: true },
    });

    const rows = await this.prisma.$queryRaw<{
      date: Date;
      type: string;
      categoryName: string;
      amount: bigint;
      description: string | null;
    }[]>`
      SELECT t.date,
             t.type,
             c.name AS "categoryName",
             t.amount,
             t.description
      FROM "Transaction" t
      JOIN "Category" c ON c.id = t."categoryId"
      WHERE t."workspaceId" = ${workspaceId}
        AND EXTRACT(YEAR FROM t.date) = ${year}
        AND EXTRACT(MONTH FROM t.date) = ${month}
      ORDER BY t.date ASC
    `;

    const BOM = '﻿';
    const headers = ['Date', 'Type', 'Category', 'Description', 'Amount', 'Currency'];
    const csvRows = rows.map((r) => [
      r.date.toISOString().split('T')[0],
      r.type,
      r.categoryName,
      r.description ?? '',
      (Number(r.amount) / 100).toFixed(2),
      workspace.currency,
    ]);

    // Prefix dangerous formula-trigger chars to prevent CSV injection in Excel/Sheets
    const sanitize = (v: string) => /^[=+\-@\t\r]/.test(v) ? `'${v}` : v;
    const escape = (v: string) => `"${sanitize(v).replace(/"/g, '""')}"`;
    const body = [headers, ...csvRows].map((row) => row.map(escape).join(',')).join('\n');

    return Buffer.from(BOM + body, 'utf-8');
  }

  async exportPdf(workspaceId: string, year: number, month: number): Promise<Readable> {
    const workspace = await this.prisma.workspace.findUniqueOrThrow({
      where: { id: workspaceId },
      select: { name: true, currency: true },
    });

    const summary = await this.getSummary(workspaceId, year, month);
    const transactions = await this.prisma.transaction.findMany({
      where: {
        workspaceId,
        date: { gte: new Date(year, month - 1, 1), lt: new Date(year, month, 1) },
      },
      include: { category: true },
      orderBy: { date: 'asc' },
    });

    const doc = new PDFDocument({ margin: 50 });
    const readable = new Readable({ read() {} });

    doc.on('data', (chunk: Buffer) => readable.push(chunk));
    doc.on('end', () => readable.push(null));

    const periodLabel = format(new Date(year, month - 1, 1), 'MMMM yyyy');
    doc
      .fontSize(18)
      .font('Helvetica-Bold')
      .text(`${workspace.name} — ${periodLabel} Report`, { align: 'center' });
    doc.fontSize(12).font('Helvetica').text(`Currency: ${workspace.currency}`, { align: 'center' });
    doc.moveDown();

    doc.font('Helvetica-Bold').text('Date          Type      Category              Amount');
    doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
    doc.font('Helvetica');
    for (const t of transactions) {
      const amtStr = `${(t.amount / 100).toFixed(2)} ${workspace.currency}`;
      doc.text(
        `${format(t.date, 'yyyy-MM-dd')}  ${t.type.padEnd(9)}  ${t.category.name.substring(0, 20).padEnd(20)}  ${amtStr}`,
      );
    }

    doc.moveDown().font('Helvetica-Bold');
    doc.text(`Total Income:   ${(summary.totalIncome / 100).toFixed(2)} ${workspace.currency}`);
    doc.text(`Total Expenses: ${(summary.totalExpense / 100).toFixed(2)} ${workspace.currency}`);
    doc.text(`Net Balance:    ${(summary.net / 100).toFixed(2)} ${workspace.currency}`);

    doc.end();
    return readable;
  }
}
