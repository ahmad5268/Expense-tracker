import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { QUEUE_NOTIFICATION_DELIVERY, JOB_SEND_IN_APP, JOB_SEND_PUSH } from '../queue.constants';

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

      const monthName = new Date(prevYear, prevMonth - 1, 1).toLocaleString('en-US', { month: 'long' });
      const formatCents = (cents: number) => (cents / 100).toFixed(2);
      const esc = (s: string) =>
        s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));

      for (const { userId } of workspace.members) {
        const notifData = {
          userId,
          type: 'MONTHLY_SUMMARY',
          payload,
          title: `${monthName} ${prevYear} Summary`,
          body: `Income: ${formatCents(totalIncome)} ${workspace.currency} / Expenses: ${formatCents(totalExpense)} ${workspace.currency}`,
        };
        await this.notificationQueue.add(JOB_SEND_IN_APP, notifData, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } });
        await this.notificationQueue.add(JOB_SEND_PUSH, notifData, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } });

        const member = await this.prisma.user.findUnique({ where: { id: userId }, select: { email: true } });
        if (member) {
          const sgMail = await import('@sendgrid/mail');
          sgMail.default.setApiKey(process.env.SENDGRID_API_KEY ?? '');
          await sgMail.default.send({
            to: member.email,
            from: process.env.SENDGRID_FROM_EMAIL ?? 'noreply@expensetracker.app',
            subject: `Your ${monthName} ${prevYear} expense summary`,
            html: `
              <h2>${esc(workspace.name)} &mdash; ${monthName} ${prevYear}</h2>
              <p>Income: <strong>${formatCents(totalIncome)} ${esc(workspace.currency)}</strong></p>
              <p>Expenses: <strong>${formatCents(totalExpense)} ${esc(workspace.currency)}</strong></p>
              <p>Net balance: <strong>${formatCents(net)} ${esc(workspace.currency)}</strong></p>
              <p><a href="${esc(process.env.FRONTEND_URL ?? '')}/${encodeURIComponent(workspace.id)}/reports">View full report</a></p>
            `,
          });
        }
      }

      this.logger.log(`Monthly summary queued for workspace ${workspace.id}`);
    }
  }
}
