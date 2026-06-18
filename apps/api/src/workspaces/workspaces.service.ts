import { Injectable, NotFoundException, ForbiddenException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';
import { UpdateWorkspaceDto } from './dto/update-workspace.dto';
import { MemberRole } from '@prisma/client';
import { addHours } from 'date-fns';

const DEFAULT_EXPENSE_CATEGORIES = [
  { name: 'Housing', icon: 'home', color: '#ef4444' },
  { name: 'Food & Dining', icon: 'restaurant', color: '#f97316' },
  { name: 'Transport', icon: 'directions_car', color: '#eab308' },
  { name: 'Healthcare', icon: 'medical_services', color: '#22c55e' },
  { name: 'Entertainment', icon: 'movie', color: '#3b82f6' },
  { name: 'Shopping', icon: 'shopping_bag', color: '#8b5cf6' },
  { name: 'Utilities', icon: 'bolt', color: '#06b6d4' },
  { name: 'Education', icon: 'school', color: '#f59e0b' },
  { name: 'Other', icon: 'category', color: '#6b7280' },
];

const DEFAULT_INCOME_CATEGORIES = [
  { name: 'Salary', icon: 'work', color: '#22c55e' },
  { name: 'Freelance', icon: 'laptop', color: '#3b82f6' },
  { name: 'Investment', icon: 'trending_up', color: '#8b5cf6' },
  { name: 'Gift', icon: 'card_giftcard', color: '#ec4899' },
  { name: 'Other', icon: 'category', color: '#6b7280' },
];

@Injectable()
export class WorkspacesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: string, dto: CreateWorkspaceDto) {
    return this.prisma.$transaction(async (tx) => {
      const workspace = await tx.workspace.create({
        data: { name: dto.name, currency: dto.currency, ownerId: userId },
      });

      await tx.workspaceMember.create({
        data: { workspaceId: workspace.id, userId, role: MemberRole.OWNER },
      });

      await tx.category.createMany({
        data: [
          ...DEFAULT_EXPENSE_CATEGORIES.map((c) => ({ ...c, workspaceId: workspace.id, type: 'EXPENSE' as const })),
          ...DEFAULT_INCOME_CATEGORIES.map((c) => ({ ...c, workspaceId: workspace.id, type: 'INCOME' as const })),
        ],
      });

      return workspace;
    });
  }

  async findAll(userId: string) {
    return this.prisma.workspace.findMany({
      where: { members: { some: { userId } } },
      include: {
        members: { select: { userId: true, role: true } },
        _count: { select: { transactions: true } },
      },
    });
  }

  async update(workspaceId: string, dto: UpdateWorkspaceDto) {
    return this.prisma.workspace.update({ where: { id: workspaceId }, data: dto });
  }

  async invite(workspaceId: string, invitedById: string, email: string) {
    const existing = await this.prisma.workspaceInvite.findFirst({
      where: { workspaceId, invitedEmail: email, status: 'PENDING' },
    });
    if (existing) throw new ConflictException('Invite already pending for this email');

    const workspace = await this.prisma.workspace.findUnique({ where: { id: workspaceId } });
    if (!workspace) throw new NotFoundException('Workspace not found');

    const invite = await this.prisma.workspaceInvite.create({
      data: { workspaceId, invitedEmail: email, invitedById, expiresAt: addHours(new Date(), 72) },
    });

    const sgMail = await import('@sendgrid/mail');
    sgMail.default.setApiKey(process.env.SENDGRID_API_KEY ?? '');
    await sgMail.default.send({
      to: email,
      from: process.env.SENDGRID_FROM_EMAIL ?? 'noreply@expensetracker.app',
      subject: `You've been invited to ${workspace.name}`,
      text: `Accept your invite: ${process.env.FRONTEND_URL}/invite/${invite.token}`,
      html: `<p>You've been invited to join <strong>${workspace.name}</strong>.</p>
             <p><a href="${process.env.FRONTEND_URL}/invite/${invite.token}">Accept invite</a> (expires in 72 hours)</p>`,
    });

    return invite;
  }

  async join(userId: string, token: string) {
    const invite = await this.prisma.workspaceInvite.findUnique({ where: { token } });

    if (!invite || invite.status !== 'PENDING' || invite.expiresAt < new Date()) {
      throw new NotFoundException('Invite not found or expired');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user?.email !== invite.invitedEmail) {
      throw new ForbiddenException('This invite was sent to a different email address');
    }

    return this.prisma.$transaction(async (tx) => {
      await tx.workspaceMember.create({
        data: { workspaceId: invite.workspaceId, userId, role: MemberRole.MEMBER },
      });
      await tx.workspaceInvite.update({ where: { id: invite.id }, data: { status: 'ACCEPTED' } });
    });
  }

  async removeMember(workspaceId: string, requesterId: string, targetUserId: string) {
    const requester = await this.prisma.workspaceMember.findUniqueOrThrow({
      where: { workspaceId_userId: { workspaceId, userId: requesterId } },
    });
    const target = await this.prisma.workspaceMember.findUniqueOrThrow({
      where: { workspaceId_userId: { workspaceId, userId: targetUserId } },
    });

    const isSelf = requesterId === targetUserId;

    if (isSelf && requester.role === MemberRole.OWNER) {
      throw new ForbiddenException('Workspace owner cannot remove themselves. Transfer ownership first.');
    }
    if (!isSelf && requester.role === MemberRole.MEMBER) {
      throw new ForbiddenException('Members can only leave the workspace, not remove others.');
    }
    if (requester.role === MemberRole.ADMIN && target.role !== MemberRole.MEMBER && !isSelf) {
      throw new ForbiddenException('Admins can only remove regular members.');
    }

    await this.prisma.workspaceMember.delete({
      where: { workspaceId_userId: { workspaceId, userId: targetUserId } },
    });
  }
}
