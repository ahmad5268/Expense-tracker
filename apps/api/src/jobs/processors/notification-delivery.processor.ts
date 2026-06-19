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
    this.logger.debug(`In-app notification saved for user ${data.userId}`);
  }

  private async sendEmail(data: { userId: string; type: string; payload: Record<string, unknown> }) {
    const user = await this.prisma.user.findUnique({ where: { id: data.userId }, select: { email: true } });
    if (!user) return;

    const sgMail = await import('@sendgrid/mail');
    sgMail.default.setApiKey(process.env.SENDGRID_API_KEY ?? '');

    const subject = data.type === 'BUDGET_ALERT'
      ? `Budget Alert: ${(data.payload as Record<string, number>).threshold}% limit reached`
      : 'Expense Tracker Notification';

    await sgMail.default.send({
      to: user.email,
      from: process.env.SENDGRID_FROM_EMAIL ?? 'noreply@expensetracker.app',
      subject,
      text: `Your budget for this period has reached ${(data.payload as Record<string, number>).threshold}% of the limit.`,
    });
  }

  private async sendPush(data: { userId: string; type: string; payload: object; title?: string; body?: string }) {
    const user = await this.prisma.user.findUnique({
      where: { id: data.userId },
      select: { fcmToken: true },
    });
    if (!user?.fcmToken) {
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
