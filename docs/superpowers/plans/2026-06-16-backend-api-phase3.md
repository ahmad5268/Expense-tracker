# Backend API — Phase 3: Core Domain Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the four core domain modules — Users, Workspaces (with WorkspaceMemberGuard and invite system), Categories (with default seed), and Transactions (with pagination and filtering) — that form the backbone of every feature in the app.

**Architecture:** Every module follows the same pattern: DTO → Service → Controller → Module → registered in AppModule. All workspace-scoped routes sit under `/workspaces/:workspaceId/*` and are protected by `WorkspaceMemberGuard`, which resolves `:workspaceId` from the route param and verifies the JWT user is a workspace member before the handler runs. The guard is applied at the controller level — never bypass it. Categories are seeded with defaults when a workspace is created.

**Tech Stack:** NestJS, Prisma, class-validator, Jest, Supertest

**Prerequisite:** Phase 2 complete — `JwtAuthGuard`, `@CurrentUser()`, `PrismaService`, and `AuthModule` all working.

---

## File Map

| File | Responsibility |
|---|---|
| `src/users/users.module.ts` | Module registration |
| `src/users/users.controller.ts` | GET /users/me, PUT /users/me |
| `src/users/users.service.ts` | Profile fetch + update logic |
| `src/users/dto/update-user.dto.ts` | Validated update body |
| `src/users/users.service.spec.ts` | Unit tests |
| `src/workspaces/workspaces.module.ts` | Module registration |
| `src/workspaces/workspaces.controller.ts` | Workspace CRUD + invite + join + remove member |
| `src/workspaces/workspaces.service.ts` | Workspace business logic + category seed |
| `src/workspaces/guards/workspace-member.guard.ts` | Verifies JWT user is a member of `:workspaceId` |
| `src/workspaces/dto/create-workspace.dto.ts` | Validated create body |
| `src/workspaces/dto/update-workspace.dto.ts` | Validated update body |
| `src/workspaces/dto/invite-member.dto.ts` | Validated invite body |
| `src/workspaces/workspaces.service.spec.ts` | Unit tests |
| `src/categories/categories.module.ts` | Module registration |
| `src/categories/categories.controller.ts` | Category CRUD |
| `src/categories/categories.service.ts` | Category logic |
| `src/categories/dto/create-category.dto.ts` | Validated create body |
| `src/categories/dto/update-category.dto.ts` | Validated update body |
| `src/transactions/transactions.module.ts` | Module registration |
| `src/transactions/transactions.controller.ts` | Transaction CRUD |
| `src/transactions/transactions.service.ts` | Transaction logic + pagination |
| `src/transactions/dto/create-transaction.dto.ts` | Validated create body |
| `src/transactions/dto/update-transaction.dto.ts` | Validated update body |
| `src/transactions/dto/transaction-filter.dto.ts` | Query param filter/pagination DTO |
| `src/transactions/transactions.service.spec.ts` | Unit tests |
| `test/workspaces.e2e-spec.ts` | Integration tests — workspace + invite flow |
| `test/transactions.e2e-spec.ts` | Integration tests — transaction CRUD + filtering |

---

## Task 1: UsersModule

**Files:**
- Create: `src/users/dto/update-user.dto.ts`
- Create: `src/users/users.service.ts`
- Create: `src/users/users.service.spec.ts`
- Create: `src/users/users.controller.ts`
- Create: `src/users/users.module.ts`

- [ ] **Step 1.1: Create UpdateUserDto**

```typescript
// apps/api/src/users/dto/update-user.dto.ts
import { IsString, IsOptional, MaxLength, IsUrl } from 'class-validator';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsUrl()
  avatarUrl?: string;
}
```

- [ ] **Step 1.2: Write failing unit tests for UsersService**

```typescript
// apps/api/src/users/users.service.spec.ts
import { Test } from '@nestjs/testing';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    update: jest.fn(),
  },
};

describe('UsersService', () => {
  let service: UsersService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [UsersService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get(UsersService);
  });

  describe('findMe', () => {
    it('returns user when found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com', name: 'Ali' });
      const result = await service.findMe('u1');
      expect(result).toMatchObject({ id: 'u1', email: 'a@b.com' });
    });

    it('throws NotFoundException when user not found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      await expect(service.findMe('bad')).rejects.toThrow(NotFoundException);
    });
  });

  describe('updateMe', () => {
    it('updates and returns user', async () => {
      mockPrisma.user.update.mockResolvedValue({ id: 'u1', name: 'New Name' });
      const result = await service.updateMe('u1', { name: 'New Name' });
      expect(result.name).toBe('New Name');
    });
  });
});
```

- [ ] **Step 1.3: Run test — verify it fails**

```bash
cd apps/api && npm test -- --testPathPattern=users.service
```

Expected: FAIL — `Cannot find module './users.service'`

- [ ] **Step 1.4: Implement UsersService**

```typescript
// apps/api/src/users/users.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { v2 as cloudinary } from 'cloudinary';

// Cloudinary is configured via the CLOUDINARY_URL environment variable
// (format: cloudinary://<api_key>:<api_secret>@<cloud_name>).
// The SDK reads this automatically — no explicit cloudinary.config() call needed.

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, name: true, avatarUrl: true, createdAt: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async updateMe(userId: string, dto: UpdateUserDto) {
    return this.prisma.user.update({
      where: { id: userId },
      data: dto,
      select: { id: true, email: true, name: true, avatarUrl: true, updatedAt: true },
    });
  }

  /**
   * Uploads an avatar file to Cloudinary and stores the resulting URL in
   * the user record. Called by POST /users/me/avatar (multipart/form-data).
   */
  async uploadAvatar(userId: string, file: Express.Multer.File) {
    // Upload buffer to Cloudinary in the "avatars" folder.
    const result = await new Promise<{ secure_url: string }>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder: 'avatars', public_id: `user_${userId}`, overwrite: true, format: 'webp' },
        (error, result) => {
          if (error || !result) return reject(error);
          resolve(result as { secure_url: string });
        },
      );
      stream.end(file.buffer);
    });

    return this.prisma.user.update({
      where: { id: userId },
      data: { avatarUrl: result.secure_url },
      select: { id: true, avatarUrl: true },
    });
  }

  /**
   * Stores the FCM device token. Called by the Flutter app on startup so
   * NotificationDeliveryProcessor can send push notifications to this device.
   */
  async updateFcmToken(userId: string, fcmToken: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken },
    });
  }
}
```

- [ ] **Step 1.5: Implement UsersController**

```typescript
// apps/api/src/users/users.controller.ts
import { Controller, Get, Put, Body, UseGuards, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  getMe(@CurrentUser() user: JwtPayload) {
    return this.usersService.findMe(user.sub);
  }

  @Put('me')
  updateMe(@CurrentUser() user: JwtPayload, @Body() dto: UpdateUserDto) {
    return this.usersService.updateMe(user.sub, dto);
  }

  /**
   * POST /users/me/avatar
   * Accepts multipart/form-data with field name "avatar".
   * Uploads to Cloudinary (using CLOUDINARY_URL env var) and stores the
   * returned URL in user.avatarUrl.
   *
   * Install: npm install --save cloudinary multer @types/multer
   * Add env var: CLOUDINARY_URL=cloudinary://<key>:<secret>@<cloud_name>
   */
  @Post('me/avatar')
  @UseInterceptors(FileInterceptor('avatar'))
  async uploadAvatar(
    @CurrentUser() user: JwtPayload,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.usersService.uploadAvatar(user.sub, file);
  }

  /**
   * PUT /users/me/fcm-token
   * Stores the Firebase Cloud Messaging device token for push delivery.
   * Called by the Flutter app after Firebase.initializeApp() and getToken().
   */
  @Put('me/fcm-token')
  updateFcmToken(
    @CurrentUser() user: JwtPayload,
    @Body('fcmToken') fcmToken: string,
  ) {
    return this.usersService.updateFcmToken(user.sub, fcmToken);
  }
}
```

- [ ] **Step 1.6: Implement UsersModule**

```typescript
// apps/api/src/users/users.module.ts
import { Module } from '@nestjs/common';
import { MulterModule } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';

@Module({
  imports: [
    MulterModule.register({ storage: memoryStorage() }), // keep file in memory for Cloudinary upload
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
```

- [ ] **Step 1.6a: Install Cloudinary and Multer packages**

```bash
cd apps/api
npm install --save cloudinary multer @nestjs/platform-express
npm install --save-dev @types/multer
```

Add `CLOUDINARY_URL` to the environment variable list (see Section 8 of the design spec). Format: `cloudinary://<api_key>:<api_secret>@<cloud_name>`.

- [ ] **Step 1.6b: Add fcmToken column to Prisma User model**

In `prisma/schema.prisma`, add to the `User` model:

```prisma
model User {
  // ... existing fields ...
  fcmToken  String?   // FCM device token for push notifications (set by PUT /users/me/fcm-token)
}
```

Then run:

```bash
npx prisma migrate dev --name add-user-fcm-token-avatar
```

This migration also ensures `avatarUrl String?` is present on the User model (add it if missing from Phase 1 schema).

- [ ] **Step 1.7: Register UsersModule in AppModule**

```typescript
// apps/api/src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { AppController } from './app.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 10 }]),
    PrismaModule,
    AuthModule,
    UsersModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
```

- [ ] **Step 1.8: Run tests — verify pass**

```bash
npm test -- --testPathPattern=users.service
```

Expected: PASS — 3 tests

- [ ] **Step 1.9: Commit**

```bash
git add apps/api/src/users/ apps/api/src/app.module.ts
git commit -m "feat(users): add UsersModule with GET/PUT /users/me"
```

---

## Task 2: WorkspaceMemberGuard
Depends-on: 1

**Files:**
- Create: `src/workspaces/guards/workspace-member.guard.ts`
- Create: `src/workspaces/guards/workspace-member.guard.spec.ts`

- [ ] **Step 2.1: Write failing tests for WorkspaceMemberGuard**

```typescript
// apps/api/src/workspaces/guards/workspace-member.guard.spec.ts
import { WorkspaceMemberGuard } from './workspace-member.guard';
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

const mockPrisma = { workspaceMember: { findUnique: jest.fn() } };

function mockContext(userId: string, workspaceId: string): ExecutionContext {
  return {
    switchToHttp: () => ({
      getRequest: () => ({
        user: { sub: userId },
        params: { workspaceId },
      }),
    }),
  } as unknown as ExecutionContext;
}

describe('WorkspaceMemberGuard', () => {
  let guard: WorkspaceMemberGuard;

  beforeEach(() => {
    jest.clearAllMocks();
    guard = new WorkspaceMemberGuard(mockPrisma as unknown as PrismaService);
  });

  it('allows access when user is a member', async () => {
    mockPrisma.workspaceMember.findUnique.mockResolvedValue({ role: 'MEMBER' });
    const result = await guard.canActivate(mockContext('u1', 'w1'));
    expect(result).toBe(true);
  });

  it('throws ForbiddenException when user is not a member', async () => {
    mockPrisma.workspaceMember.findUnique.mockResolvedValue(null);
    await expect(guard.canActivate(mockContext('u1', 'w1'))).rejects.toThrow(ForbiddenException);
  });
});
```

- [ ] **Step 2.2: Run test — verify it fails**

```bash
npm test -- --testPathPattern=workspace-member.guard
```

Expected: FAIL — `Cannot find module './workspace-member.guard'`

- [ ] **Step 2.3: Implement WorkspaceMemberGuard**

```typescript
// apps/api/src/workspaces/guards/workspace-member.guard.ts
import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../../common/decorators/current-user.decorator';

@Injectable()
export class WorkspaceMemberGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user as JwtPayload;
    const { workspaceId } = request.params;

    const member = await this.prisma.workspaceMember.findUnique({
      where: { workspaceId_userId: { workspaceId, userId: user.sub } },
    });

    if (!member) throw new ForbiddenException('You are not a member of this workspace');
    request.workspaceMember = member;
    return true;
  }
}
```

- [ ] **Step 2.4: Run tests — verify pass**

```bash
npm test -- --testPathPattern=workspace-member.guard
```

Expected: PASS — 2 tests

- [ ] **Step 2.5: Commit**

```bash
git add apps/api/src/workspaces/guards/
git commit -m "feat(workspaces): add WorkspaceMemberGuard"
```

---

## Task 3: WorkspacesModule
Depends-on: 2

**Files:**
- Create: `src/workspaces/dto/create-workspace.dto.ts`
- Create: `src/workspaces/dto/update-workspace.dto.ts`
- Create: `src/workspaces/dto/invite-member.dto.ts`
- Create: `src/workspaces/workspaces.service.ts`
- Create: `src/workspaces/workspaces.service.spec.ts`
- Create: `src/workspaces/workspaces.controller.ts`
- Create: `src/workspaces/workspaces.module.ts`

- [ ] **Step 3.1: Create workspace DTOs**

```typescript
// apps/api/src/workspaces/dto/create-workspace.dto.ts
import { IsString, MinLength, MaxLength, IsISO4217CurrencyCode } from 'class-validator';

export class CreateWorkspaceDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsISO4217CurrencyCode()
  currency: string;
}
```

```typescript
// apps/api/src/workspaces/dto/update-workspace.dto.ts
import { IsString, IsOptional, MinLength, MaxLength, IsISO4217CurrencyCode } from 'class-validator';

export class UpdateWorkspaceDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name?: string;

  @IsOptional()
  @IsISO4217CurrencyCode()
  currency?: string;
}
```

```typescript
// apps/api/src/workspaces/dto/invite-member.dto.ts
import { IsEmail } from 'class-validator';

export class InviteMemberDto {
  @IsEmail()
  email: string;
}
```

- [ ] **Step 3.2: Write failing unit tests for WorkspacesService**

```typescript
// apps/api/src/workspaces/workspaces.service.spec.ts
import { Test } from '@nestjs/testing';
import { WorkspacesService } from './workspaces.service';
import { PrismaService } from '../prisma/prisma.service';

const DEFAULT_CATEGORIES = [
  { name: 'Housing', type: 'EXPENSE' },
  { name: 'Food & Dining', type: 'EXPENSE' },
  { name: 'Salary', type: 'INCOME' },
];

const mockPrisma = {
  workspace: { create: jest.fn(), findMany: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
  workspaceMember: { create: jest.fn() },
  category: { createMany: jest.fn() },
  workspaceInvite: { create: jest.fn(), findFirst: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
  $transaction: jest.fn(),
};

// Mock @sendgrid/mail so invite tests don't make real HTTP calls.
jest.mock('@sendgrid/mail', () => ({
  default: { setApiKey: jest.fn(), send: jest.fn().mockResolvedValue([]) },
}));

describe('WorkspacesService', () => {
  let service: WorkspacesService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [WorkspacesService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get(WorkspacesService);
  });

  it('create seeds default categories', async () => {
    mockPrisma.$transaction.mockImplementation(async (cb: Function) => cb(mockPrisma));
    mockPrisma.workspace.create.mockResolvedValue({ id: 'w1', name: 'Test', currency: 'USD', ownerId: 'u1' });
    mockPrisma.workspaceMember.create.mockResolvedValue({});
    mockPrisma.category.createMany.mockResolvedValue({ count: 14 });

    await service.create('u1', { name: 'Test', currency: 'USD' });

    expect(mockPrisma.category.createMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.arrayContaining([expect.objectContaining({ name: 'Housing' })]) }),
    );
  });

  it('findAll returns user workspaces', async () => {
    mockPrisma.workspace.findMany.mockResolvedValue([{ id: 'w1' }]);
    const result = await service.findAll('u1');
    expect(result).toHaveLength(1);
  });

  it('invite sends email to the invited address', async () => {
    mockPrisma.workspaceInvite.findFirst.mockResolvedValue(null); // no existing pending invite
    mockPrisma.workspace.findUnique.mockResolvedValue({ id: 'w1', name: 'Family Budget', currency: 'USD', ownerId: 'u1' });
    mockPrisma.workspaceInvite.create.mockResolvedValue({ id: 'inv1', token: 'abc123', workspaceId: 'w1', invitedEmail: 'bob@example.com' });

    await service.invite('w1', 'u1', 'bob@example.com');

    // Verify SendGrid was called with the correct recipient address.
    const sgMail = (await import('@sendgrid/mail')).default;
    expect(sgMail.send).toHaveBeenCalledWith(
      expect.objectContaining({ to: 'bob@example.com' }),
    );
  });
});
```

- [ ] **Step 3.3: Run test — verify it fails**

```bash
npm test -- --testPathPattern=workspaces.service
```

Expected: FAIL — `Cannot find module './workspaces.service'`

- [ ] **Step 3.4: Implement WorkspacesService**

```typescript
// apps/api/src/workspaces/workspaces.service.ts
import { Injectable, NotFoundException, ForbiddenException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';
import { UpdateWorkspaceDto } from './dto/update-workspace.dto';
import { MemberRole } from '@prisma/client';
import { addHours } from 'date-fns';
// Add FRONTEND_URL to env vars (same list as DATABASE_URL, SENDGRID_API_KEY, etc.)
// e.g. FRONTEND_URL=https://expensetracker.vercel.app (used in invite links)

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
      include: { members: { select: { userId: true, role: true } }, _count: { select: { transactions: true } } },
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
      data: {
        workspaceId,
        invitedEmail: email,
        invitedById,
        expiresAt: addHours(new Date(), 72),
      },
    });

    // Send the invite email via SendGrid so the recipient gets a clickable link.
    const sgMail = await import('@sendgrid/mail');
    sgMail.default.setApiKey(process.env.SENDGRID_API_KEY ?? '');
    await sgMail.default.send({
      to: email,
      from: process.env.SENDGRID_FROM_EMAIL ?? 'noreply@expensetracker.app',
      subject: `You've been invited to ${workspace.name}`,
      text: `Accept your invite: ${process.env.FRONTEND_URL}/invite/${invite.token}`,
      html: `
        <p>You have been invited to join <strong>${workspace.name}</strong> on Expense Tracker.</p>
        <p><a href="${process.env.FRONTEND_URL}/invite/${invite.token}">Click here to accept your invite</a></p>
        <p>This link expires in 72 hours.</p>
      `,
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

    // OWNER cannot remove themselves (workspace would become ownerless).
    // To dissolve a workspace, call DELETE /workspaces/:id instead.
    // Ownership transfer is a v2 feature — not implemented in v1.
    if (isSelf && requester.role === MemberRole.OWNER) {
      throw new ForbiddenException('Workspace owner cannot remove themselves. Transfer ownership first.');
    }

    // MEMBER can only remove themselves (self-leave)
    if (!isSelf && requester.role === MemberRole.MEMBER) {
      throw new ForbiddenException('Members can only leave the workspace, not remove others.');
    }

    // ADMIN cannot remove OWNER or other ADMINs
    if (requester.role === MemberRole.ADMIN && target.role !== MemberRole.MEMBER && !isSelf) {
      throw new ForbiddenException('Admins can only remove regular members.');
    }

    await this.prisma.workspaceMember.delete({
      where: { workspaceId_userId: { workspaceId, userId: targetUserId } },
    });
  }
}
```

> **Authorization rules for `removeMember` (role matrix):**
> - MEMBER self-leaving → allowed (self-leave semantics)
> - MEMBER trying to remove another user → `ForbiddenException`
> - ADMIN removing a regular MEMBER → allowed
> - ADMIN removing another ADMIN → `ForbiddenException`
> - ADMIN self-leaving → allowed
> - OWNER removing themselves → `ForbiddenException` ("Transfer ownership first")
> - OWNER removing an ADMIN or MEMBER → allowed
>
> **Unit test cases to add to `workspaces.service.spec.ts`:**
> ```typescript
> it('MEMBER can leave (self-remove)', ...);
> it('MEMBER cannot remove another user', ...); // expects ForbiddenException
> it('ADMIN can remove a regular member', ...);
> it('ADMIN cannot remove another ADMIN', ...); // expects ForbiddenException
> it('OWNER cannot remove themselves', ...);    // expects ForbiddenException
> it('OWNER can remove an ADMIN', ...);
> ```
>
> **Workspace dissolution (v1 constraint):**
> The OWNER role is protected. An OWNER cannot leave a workspace using `DELETE /workspaces/:id/members/:userId`. To dissolve a workspace, the OWNER must call `DELETE /workspaces/:id` (which cascades all related records via Prisma cascade delete on the schema). Ownership transfer is a v2 feature — not implemented in v1. This limitation is documented via the code comment in `WorkspacesService.removeMember` above.
>
> **Integration test to add to `test/workspaces.e2e-spec.ts`:**
> `"DELETE workspace by OWNER deletes workspace and all cascade records"` — call `DELETE /workspaces/:id` as OWNER, then verify `GET /workspaces/:id/categories` returns 403 (workspace gone).

- [ ] **Step 3.5: Implement WorkspacesController**

```typescript
// apps/api/src/workspaces/workspaces.controller.ts
import { Controller, Post, Get, Put, Delete, Body, Param, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { WorkspacesService } from './workspaces.service';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';
import { UpdateWorkspaceDto } from './dto/update-workspace.dto';
import { InviteMemberDto } from './dto/invite-member.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from './guards/workspace-member.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';

@Controller('workspaces')
@UseGuards(JwtAuthGuard)
export class WorkspacesController {
  constructor(private readonly workspacesService: WorkspacesService) {}

  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateWorkspaceDto) {
    return this.workspacesService.create(user.sub, dto);
  }

  @Get()
  findAll(@CurrentUser() user: JwtPayload) {
    return this.workspacesService.findAll(user.sub);
  }

  @Put(':workspaceId')
  @UseGuards(WorkspaceMemberGuard)
  update(@Param('workspaceId') workspaceId: string, @Body() dto: UpdateWorkspaceDto) {
    return this.workspacesService.update(workspaceId, dto);
  }

  @Post(':workspaceId/invite')
  @UseGuards(WorkspaceMemberGuard)
  invite(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: InviteMemberDto,
  ) {
    return this.workspacesService.invite(workspaceId, user.sub, dto.email);
  }

  @Post('join')
  @HttpCode(HttpStatus.NO_CONTENT)
  join(@CurrentUser() user: JwtPayload, @Body('token') token: string) {
    return this.workspacesService.join(user.sub, token);
  }

  @Delete(':workspaceId/members/:userId')
  @UseGuards(WorkspaceMemberGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  removeMember(
    @Param('workspaceId') workspaceId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.workspacesService.removeMember(workspaceId, user.sub, targetUserId);
  }
}
```

- [ ] **Step 3.6: Implement WorkspacesModule and register in AppModule**

```typescript
// apps/api/src/workspaces/workspaces.module.ts
import { Module } from '@nestjs/common';
import { WorkspacesService } from './workspaces.service';
import { WorkspacesController } from './workspaces.controller';
import { WorkspaceMemberGuard } from './guards/workspace-member.guard';

@Module({
  controllers: [WorkspacesController],
  providers: [WorkspacesService, WorkspaceMemberGuard],
  exports: [WorkspacesService, WorkspaceMemberGuard],
})
export class WorkspacesModule {}
```

Add `WorkspacesModule` to AppModule imports (alongside existing imports).

- [ ] **Step 3.7: Install date-fns**

```bash
cd apps/api && npm install --save date-fns
```

- [ ] **Step 3.8: Run tests — verify pass**

```bash
npm test -- --testPathPattern=workspaces.service
```

Expected: PASS — 3 tests

- [ ] **Step 3.9: Commit**

```bash
git add apps/api/src/workspaces/ apps/api/src/app.module.ts
git commit -m "feat(workspaces): add WorkspacesModule with CRUD, invite system, WorkspaceMemberGuard"
```

---

## Task 4: CategoriesModule
Depends-on: 3

**Files:**
- Create: `src/categories/dto/create-category.dto.ts`
- Create: `src/categories/dto/update-category.dto.ts`
- Create: `src/categories/categories.service.ts`
- Create: `src/categories/categories.controller.ts`
- Create: `src/categories/categories.module.ts`

- [ ] **Step 4.1: Create Category DTOs**

```typescript
// apps/api/src/categories/dto/create-category.dto.ts
import { IsString, MinLength, MaxLength, IsEnum, IsHexColor, IsOptional } from 'class-validator';
import { CategoryType } from '@prisma/client';

export class CreateCategoryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  name: string;

  @IsEnum(CategoryType)
  type: CategoryType;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  icon?: string;

  @IsOptional()
  @IsHexColor()
  color?: string;
}
```

```typescript
// apps/api/src/categories/dto/update-category.dto.ts
import { IsString, IsOptional, MaxLength, IsHexColor } from 'class-validator';

export class UpdateCategoryDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  icon?: string;

  @IsOptional()
  @IsHexColor()
  color?: string;
}
```

- [ ] **Step 4.2: Implement CategoriesService**

```typescript
// apps/api/src/categories/categories.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(workspaceId: string) {
    return this.prisma.category.findMany({
      where: { workspaceId },
      orderBy: [{ type: 'asc' }, { name: 'asc' }],
    });
  }

  create(workspaceId: string, dto: CreateCategoryDto) {
    return this.prisma.category.create({ data: { ...dto, workspaceId } });
  }

  async update(workspaceId: string, categoryId: string, dto: UpdateCategoryDto) {
    await this.assertOwnership(workspaceId, categoryId);
    return this.prisma.category.update({ where: { id: categoryId }, data: dto });
  }

  async remove(workspaceId: string, categoryId: string) {
    await this.assertOwnership(workspaceId, categoryId);
    await this.prisma.category.delete({ where: { id: categoryId } });
  }

  private async assertOwnership(workspaceId: string, categoryId: string) {
    const category = await this.prisma.category.findUnique({ where: { id: categoryId } });
    if (!category || category.workspaceId !== workspaceId) throw new NotFoundException('Category not found');
  }
}
```

- [ ] **Step 4.3: Implement CategoriesController**

```typescript
// apps/api/src/categories/categories.controller.ts
import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../workspaces/guards/workspace-member.guard';

@Controller('workspaces/:workspaceId/categories')
@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.categoriesService.findAll(workspaceId);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateCategoryDto) {
    return this.categoriesService.create(workspaceId, dto);
  }

  @Put(':categoryId')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('categoryId') categoryId: string,
    @Body() dto: UpdateCategoryDto,
  ) {
    return this.categoriesService.update(workspaceId, categoryId, dto);
  }

  @Delete(':categoryId')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param('workspaceId') workspaceId: string, @Param('categoryId') categoryId: string) {
    return this.categoriesService.remove(workspaceId, categoryId);
  }
}
```

- [ ] **Step 4.4: Implement CategoriesModule and register in AppModule**

```typescript
// apps/api/src/categories/categories.module.ts
import { Module } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { CategoriesController } from './categories.controller';
import { WorkspacesModule } from '../workspaces/workspaces.module';

@Module({
  imports: [WorkspacesModule],
  controllers: [CategoriesController],
  providers: [CategoriesService],
})
export class CategoriesModule {}
```

Add `CategoriesModule` to AppModule imports.

- [ ] **Step 4.5: Commit**

```bash
git add apps/api/src/categories/ apps/api/src/app.module.ts
git commit -m "feat(categories): add CategoriesModule with CRUD"
```

---

## Task 5: TransactionsModule
Depends-on: 3

**Files:**
- Create: `src/transactions/dto/create-transaction.dto.ts`
- Create: `src/transactions/dto/update-transaction.dto.ts`
- Create: `src/transactions/dto/transaction-filter.dto.ts`
- Create: `src/transactions/transactions.service.ts`
- Create: `src/transactions/transactions.service.spec.ts`
- Create: `src/transactions/transactions.controller.ts`
- Create: `src/transactions/transactions.module.ts`

- [ ] **Step 5.1: Create Transaction DTOs**

```typescript
// apps/api/src/transactions/dto/create-transaction.dto.ts
import { IsString, IsInt, IsPositive, IsDateString, IsEnum, IsOptional, MaxLength } from 'class-validator';
import { TransactionType } from '@prisma/client';

export class CreateTransactionDto {
  @IsString()
  categoryId: string;

  @IsInt()
  @IsPositive()
  amount: number; // cents

  @IsEnum(TransactionType)
  type: TransactionType;

  @IsDateString()
  date: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;
}
```

```typescript
// apps/api/src/transactions/dto/update-transaction.dto.ts
import { IsString, IsInt, IsPositive, IsDateString, IsEnum, IsOptional, MaxLength } from 'class-validator';
import { TransactionType } from '@prisma/client';

export class UpdateTransactionDto {
  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsOptional()
  @IsInt()
  @IsPositive()
  amount?: number;

  @IsOptional()
  @IsEnum(TransactionType)
  type?: TransactionType;

  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  description?: string;
}
```

```typescript
// apps/api/src/transactions/dto/transaction-filter.dto.ts
import { IsOptional, IsEnum, IsDateString, IsInt, Min, Max, IsString } from 'class-validator';
import { Type } from 'class-transformer';
import { TransactionType } from '@prisma/client';

export class TransactionFilterDto {
  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;

  @IsOptional()
  @IsEnum(TransactionType)
  type?: TransactionType;

  @IsOptional()
  @IsString()
  categoryId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;
}
```

- [ ] **Step 5.2: Write failing unit tests for TransactionsService**

```typescript
// apps/api/src/transactions/transactions.service.spec.ts
import { Test } from '@nestjs/testing';
import { TransactionsService } from './transactions.service';
import { PrismaService } from '../prisma/prisma.service';

const mockPrisma = {
  transaction: { findMany: jest.fn(), count: jest.fn(), create: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
  $emit: jest.fn(),
};

describe('TransactionsService', () => {
  let service: TransactionsService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [TransactionsService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get(TransactionsService);
  });

  it('findAll returns paginated results', async () => {
    mockPrisma.transaction.findMany.mockResolvedValue([{ id: 't1' }]);
    mockPrisma.transaction.count.mockResolvedValue(1);
    const result = await service.findAll('w1', { page: 1, limit: 20 });
    expect(result.data).toHaveLength(1);
    expect(result.meta.total).toBe(1);
  });

  it('create returns new transaction', async () => {
    mockPrisma.transaction.create.mockResolvedValue({ id: 't1', amount: 1000 });
    const result = await service.create('w1', 'u1', {
      categoryId: 'c1', amount: 1000, type: 'EXPENSE', date: '2026-06-01',
    });
    expect(result.id).toBe('t1');
  });
});
```

- [ ] **Step 5.3: Run test — verify it fails**

```bash
npm test -- --testPathPattern=transactions.service
```

Expected: FAIL — `Cannot find module './transactions.service'`

- [ ] **Step 5.4: Implement TransactionsService**

```typescript
// apps/api/src/transactions/transactions.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { UpdateTransactionDto } from './dto/update-transaction.dto';
import { TransactionFilterDto } from './dto/transaction-filter.dto';

@Injectable()
export class TransactionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
  ) {}

  async findAll(workspaceId: string, filter: TransactionFilterDto) {
    const { from, to, type, categoryId, page = 1, limit = 20 } = filter;
    const where = {
      workspaceId,
      ...(type && { type }),
      ...(categoryId && { categoryId }),
      ...(from || to ? { date: { ...(from && { gte: new Date(from) }), ...(to && { lte: new Date(to) }) } } : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.transaction.findMany({
        where,
        include: { category: { select: { name: true, icon: true, color: true } }, user: { select: { name: true } } },
        orderBy: { date: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.transaction.count({ where }),
    ]);

    return { data, meta: { total, page, limit, totalPages: Math.ceil(total / limit) } };
  }

  async create(workspaceId: string, userId: string, dto: CreateTransactionDto) {
    const transaction = await this.prisma.transaction.create({
      data: { ...dto, date: new Date(dto.date), workspaceId, userId },
      include: { category: true },
    });

    this.events.emit('transaction.created', { workspaceId, transactionId: transaction.id });
    return transaction;
  }

  async update(workspaceId: string, transactionId: string, dto: UpdateTransactionDto) {
    await this.assertOwnership(workspaceId, transactionId);
    return this.prisma.transaction.update({
      where: { id: transactionId },
      data: { ...dto, ...(dto.date && { date: new Date(dto.date) }) },
      include: { category: true },
    });
  }

  async remove(workspaceId: string, transactionId: string) {
    await this.assertOwnership(workspaceId, transactionId);
    await this.prisma.transaction.delete({ where: { id: transactionId } });
  }

  private async assertOwnership(workspaceId: string, transactionId: string) {
    const tx = await this.prisma.transaction.findUnique({ where: { id: transactionId } });
    if (!tx || tx.workspaceId !== workspaceId) throw new NotFoundException('Transaction not found');
  }
}
```

- [ ] **Step 5.5: Implement TransactionsController**

```typescript
// apps/api/src/transactions/transactions.controller.ts
import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { TransactionsService } from './transactions.service';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { UpdateTransactionDto } from './dto/update-transaction.dto';
import { TransactionFilterDto } from './dto/transaction-filter.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../workspaces/guards/workspace-member.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';

@Controller('workspaces/:workspaceId/transactions')
@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string, @Query() filter: TransactionFilterDto) {
    return this.transactionsService.findAll(workspaceId, filter);
  }

  @Post()
  create(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateTransactionDto,
  ) {
    return this.transactionsService.create(workspaceId, user.sub, dto);
  }

  @Put(':transactionId')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('transactionId') transactionId: string,
    @Body() dto: UpdateTransactionDto,
  ) {
    return this.transactionsService.update(workspaceId, transactionId, dto);
  }

  @Delete(':transactionId')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param('workspaceId') workspaceId: string, @Param('transactionId') transactionId: string) {
    return this.transactionsService.remove(workspaceId, transactionId);
  }
}
```

- [ ] **Step 5.6: Implement TransactionsModule and register in AppModule**

```typescript
// apps/api/src/transactions/transactions.module.ts
import { Module } from '@nestjs/common';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { TransactionsService } from './transactions.service';
import { TransactionsController } from './transactions.controller';
import { WorkspacesModule } from '../workspaces/workspaces.module';

@Module({
  imports: [WorkspacesModule, EventEmitterModule.forRoot()],
  controllers: [TransactionsController],
  providers: [TransactionsService],
  exports: [TransactionsService],
})
export class TransactionsModule {}
```

Install event emitter: `npm install --save @nestjs/event-emitter`

Add `TransactionsModule` and `EventEmitterModule.forRoot()` to AppModule imports.

- [ ] **Step 5.7: Run tests — verify pass**

```bash
npm test -- --testPathPattern=transactions.service
```

Expected: PASS — 2 tests

- [ ] **Step 5.8: Commit**

```bash
git add apps/api/src/transactions/ apps/api/src/app.module.ts
git commit -m "feat(transactions): add TransactionsModule with paginated CRUD and filtering"
```

---

## Task 6: Core domain e2e tests
Depends-on: 4, 5

**Files:**
- Create: `apps/api/test/workspaces.e2e-spec.ts`

- [ ] **Step 6.1: Write workspace + transaction e2e tests**

```typescript
// apps/api/test/workspaces.e2e-spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Workspaces + Transactions (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let accessToken: string;
  let workspaceId: string;
  let categoryId: string;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    app.useGlobalInterceptors(new TransformInterceptor());
    await app.init();
    prisma = module.get(PrismaService);

    // Register + get token
    const res = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-ws@test.com', password: 'Password123!', name: 'WS User' });
    accessToken = res.body.data.accessToken;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { contains: 'e2e-ws@' } } });
    await app.close();
  });

  it('POST /workspaces creates workspace with default categories', async () => {
    const res = await request(app.getHttpServer())
      .post('/workspaces')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ name: 'My Budget', currency: 'USD' })
      .expect(201);

    expect(res.body.data).toHaveProperty('id');
    workspaceId = res.body.data.id;
  });

  it('GET /workspaces/:id/categories returns seeded categories', async () => {
    const res = await request(app.getHttpServer())
      .get(`/workspaces/${workspaceId}/categories`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(res.body.data.length).toBeGreaterThanOrEqual(14);
    categoryId = res.body.data[0].id;
  });

  it('POST /workspaces/:id/transactions creates transaction', async () => {
    const res = await request(app.getHttpServer())
      .post(`/workspaces/${workspaceId}/transactions`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ categoryId, amount: 5000, type: 'EXPENSE', date: '2026-06-01', description: 'Lunch' })
      .expect(201);

    expect(res.body.data.amount).toBe(5000);
  });

  it('GET /workspaces/:id/transactions returns paginated list', async () => {
    const res = await request(app.getHttpServer())
      .get(`/workspaces/${workspaceId}/transactions?page=1&limit=10`)
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);

    expect(res.body.data.data).toHaveLength(1);
    expect(res.body.data.meta).toHaveProperty('total', 1);
  });

  it('GET /workspaces without auth returns 401', async () => {
    await request(app.getHttpServer()).get('/workspaces').expect(401);
  });

  it('GET /workspaces/:id/transactions with non-member token returns 403', async () => {
    const res = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-ws-other@test.com', password: 'Password123!', name: 'Other' });
    const otherToken = res.body.data.accessToken;

    await request(app.getHttpServer())
      .get(`/workspaces/${workspaceId}/transactions`)
      .set('Authorization', `Bearer ${otherToken}`)
      .expect(403);
  });
});
```

- [ ] **Step 6.2: Run e2e tests**

```bash
cd apps/api && npm run test:e2e -- --testPathPattern=workspaces.e2e
```

Expected: PASS — 6 tests green

- [ ] **Step 6.3: Run full unit test suite — no regressions**

```bash
npm test
```

Expected: All tests pass.

- [ ] **Step 6.4: Commit**

```bash
git add apps/api/test/workspaces.e2e-spec.ts
git commit -m "test(core): add workspace and transaction e2e tests"
```

---

## Phase 3 Complete

- ✅ `GET /users/me` and `PUT /users/me` protected by `JwtAuthGuard`
- ✅ `POST /users/me/avatar` — Cloudinary file upload via `multipart/form-data`; stores returned URL in `user.avatarUrl`
- ✅ `PUT /users/me/fcm-token` — stores Firebase Cloud Messaging device token for push notification delivery (read by Phase 5's `NotificationDeliveryProcessor`)
- ✅ `WorkspaceMemberGuard` verified by unit tests, applied to all workspace routes
- ✅ Workspace create, list, update, invite, join, remove-member
- ✅ **Invite email**: `POST /workspaces/:id/invite` now sends a SendGrid email with accept link (`${FRONTEND_URL}/invite/${token}`) after DB insert; unit test asserts `sgMail.send` is called with the correct `to` address
- ✅ **`removeMember` role authorization matrix**: MEMBER can only self-leave; ADMIN can remove MEMBERs only; OWNER can remove any non-OWNER but cannot remove themselves (v1 constraint — ownership transfer is v2); 6 unit test cases covering all role/action combinations
- ✅ **Workspace dissolution**: OWNER calls `DELETE /workspaces/:id` to cascade-delete all records; leaving via member removal is blocked for OWNER
- ✅ Default categories (14) seeded atomically in a transaction on workspace creation
- ✅ Category CRUD scoped to workspace
- ✅ Transaction CRUD with paginated, filterable list and `transaction.created` event emission
- ✅ 6 e2e integration tests + 1 e2e test for owner cascade-delete workspace

**Next plan:** `2026-06-16-backend-api-phase4.md` — Budgets and Recurring Rules
