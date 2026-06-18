# Backend API — Phase 6: Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `NotificationsModule` with REST endpoints for listing/reading notifications, and a WebSocket gateway (`/notifications`) for real-time in-app delivery backed by Redis pub/sub. The `NotificationDeliveryProcessor` (Phase 5) already writes to the DB — this module exposes CRUD and pushes live events over WebSocket when a notification is saved.

**Architecture:** `NotificationsModule` exports `NotificationsService`. The `NotificationsGateway` (Socket.IO) authenticates via JWT on handshake and joins the user to a room named after their `userId`. When a notification row is inserted, `NotificationsService.push()` publishes to Redis; `NotificationsGateway` subscribes and emits to the correct room. This avoids tight coupling between the job processor and the gateway.

**Tech Stack:** `@nestjs/websockets`, `@nestjs/platform-socket.io`, `socket.io`, `ioredis` (for pub/sub channel)

**Prerequisite:** Phase 5 complete. `PrismaService`, `AuthModule` (JWT strategy), and `NotificationType` enum are available.

---

## File Map

| File | Responsibility |
|---|---|
| `src/notifications/notifications.module.ts` | Module wiring |
| `src/notifications/notifications.service.ts` | DB CRUD + Redis publish |
| `src/notifications/notifications.service.spec.ts` | Unit tests |
| `src/notifications/notifications.controller.ts` | REST endpoints (`GET /`, `PATCH /:id/read`, `PATCH /read-all`, `DELETE /:id`) |
| `src/notifications/notifications.controller.spec.ts` | Controller unit tests |
| `src/notifications/notifications.gateway.ts` | WebSocket gateway — JWT auth on handshake, Redis subscribe, emit to user room |
| `src/notifications/dto/notification-query.dto.ts` | Query params DTO |

---

## Task 1: NotificationsModule + NotificationsService

**Files:**
- Create: `src/notifications/notifications.module.ts`
- Create: `src/notifications/dto/notification-query.dto.ts`
- Create: `src/notifications/notifications.service.ts`
- Create: `src/notifications/notifications.service.spec.ts`

- [ ] **Step 1.1: Write failing unit tests**

```typescript
// apps/api/src/notifications/notifications.service.spec.ts
import { Test } from '@nestjs/testing';
import { NotificationsService } from './notifications.service';
import { PrismaService } from '../prisma/prisma.service';

const mockPrisma = {
  notification: {
    findMany: jest.fn(),
    count: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
    delete: jest.fn(),
  },
};

describe('NotificationsService', () => {
  let service: NotificationsService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();
    service = module.get(NotificationsService);
  });

  describe('findAll', () => {
    it('returns paginated notifications for user', async () => {
      mockPrisma.notification.findMany.mockResolvedValue([{ id: 'n1', userId: 'u1', isRead: false }]);
      mockPrisma.notification.count.mockResolvedValue(1);
      const result = await service.findAll('u1', { page: 1, limit: 20 });
      expect(result.data).toHaveLength(1);
      expect(result.total).toBe(1);
      expect(mockPrisma.notification.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { userId: 'u1' } }),
      );
    });
  });

  describe('markRead', () => {
    it('marks a single notification as read', async () => {
      mockPrisma.notification.update.mockResolvedValue({ id: 'n1', isRead: true });
      await service.markRead('u1', 'n1');
      expect(mockPrisma.notification.update).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: 'n1', userId: 'u1' } }),
      );
    });
  });

  describe('markAllRead', () => {
    it('marks all notifications as read for user', async () => {
      mockPrisma.notification.updateMany.mockResolvedValue({ count: 5 });
      await service.markAllRead('u1');
      expect(mockPrisma.notification.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { userId: 'u1', isRead: false } }),
      );
    });
  });

  describe('remove', () => {
    it('deletes a notification owned by the user', async () => {
      mockPrisma.notification.delete.mockResolvedValue({ id: 'n1' });
      await service.remove('u1', 'n1');
      expect(mockPrisma.notification.delete).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: 'n1', userId: 'u1' } }),
      );
    });
  });
});
```

- [ ] **Step 1.2: Run test — verify it fails**

```bash
cd apps/api && npm test -- --testPathPattern=notifications.service
```

Expected: FAIL — `Cannot find module './notifications.service'`

- [ ] **Step 1.3: Create DTO**

```typescript
// apps/api/src/notifications/dto/notification-query.dto.ts
import { IsInt, IsOptional, Min, Max } from 'class-validator';
import { Type } from 'class-transformer';

export class NotificationQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1)
  page?: number = 1;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  limit?: number = 20;
}
```

- [ ] **Step 1.4: Implement NotificationsService**

```typescript
// apps/api/src/notifications/notifications.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationQueryDto } from './dto/notification-query.dto';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(userId: string, query: NotificationQueryDto) {
    const { page = 1, limit = 20 } = query;
    const skip = (page - 1) * limit;

    const [data, total] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.notification.count({ where: { userId } }),
    ]);

    return { data, total, page, limit, totalPages: Math.ceil(total / limit) };
  }

  async markRead(userId: string, notificationId: string) {
    return this.prisma.notification.update({
      where: { id: notificationId, userId },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async markAllRead(userId: string) {
    return this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async remove(userId: string, notificationId: string) {
    return this.prisma.notification.delete({
      where: { id: notificationId, userId },
    });
  }

  async push(userId: string, type: string, payload: object) {
    const notification = await this.prisma.notification.create({
      data: { userId, type: type as any, payload },
    });
    return notification;
  }
}
```

- [ ] **Step 1.5: Run tests — verify pass**

```bash
npm test -- --testPathPattern=notifications.service
```

Expected: PASS — 4 tests

- [ ] **Step 1.6: Commit**

```bash
git add apps/api/src/notifications/
git commit -m "feat(notifications): add NotificationsService with CRUD"
```

---

## Task 2: NotificationsController
Depends-on: 1

**Files:**
- Create: `src/notifications/notifications.controller.ts`
- Create: `src/notifications/notifications.controller.spec.ts`

- [ ] **Step 2.1: Write failing unit tests**

```typescript
// apps/api/src/notifications/notifications.controller.spec.ts
import { Test } from '@nestjs/testing';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

const mockService = {
  findAll: jest.fn(),
  markRead: jest.fn(),
  markAllRead: jest.fn(),
  remove: jest.fn(),
};

const user = { sub: 'u1', email: 'test@example.com' };

describe('NotificationsController', () => {
  let controller: NotificationsController;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      controllers: [NotificationsController],
      providers: [{ provide: NotificationsService, useValue: mockService }],
    }).compile();
    controller = module.get(NotificationsController);
  });

  it('GET / calls findAll with userId', async () => {
    mockService.findAll.mockResolvedValue({ data: [], total: 0, page: 1, limit: 20, totalPages: 0 });
    await controller.findAll(user, {});
    expect(mockService.findAll).toHaveBeenCalledWith('u1', {});
  });

  it('PATCH /:id/read calls markRead', async () => {
    mockService.markRead.mockResolvedValue({ id: 'n1', isRead: true });
    await controller.markRead(user, 'n1');
    expect(mockService.markRead).toHaveBeenCalledWith('u1', 'n1');
  });

  it('PATCH /read-all calls markAllRead', async () => {
    mockService.markAllRead.mockResolvedValue({ count: 3 });
    await controller.markAllRead(user);
    expect(mockService.markAllRead).toHaveBeenCalledWith('u1');
  });

  it('DELETE /:id calls remove', async () => {
    mockService.remove.mockResolvedValue({ id: 'n1' });
    await controller.remove(user, 'n1');
    expect(mockService.remove).toHaveBeenCalledWith('u1', 'n1');
  });
});
```

- [ ] **Step 2.2: Run test — verify it fails**

```bash
npm test -- --testPathPattern=notifications.controller
```

Expected: FAIL — `Cannot find module './notifications.controller'`

- [ ] **Step 2.3: Implement NotificationsController**

```typescript
// apps/api/src/notifications/notifications.controller.ts
import { Controller, Get, Patch, Delete, Param, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';
import { NotificationQueryDto } from './dto/notification-query.dto';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly service: NotificationsService) {}

  @Get()
  findAll(@CurrentUser() user: JwtPayload, @Query() query: NotificationQueryDto) {
    return this.service.findAll(user.sub, query);
  }

  @Patch('read-all')
  markAllRead(@CurrentUser() user: JwtPayload) {
    return this.service.markAllRead(user.sub);
  }

  @Patch(':id/read')
  markRead(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.service.markRead(user.sub, id);
  }

  @Delete(':id')
  remove(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.service.remove(user.sub, id);
  }
}
```

- [ ] **Step 2.4: Run tests — verify pass**

```bash
npm test -- --testPathPattern=notifications.controller
```

Expected: PASS — 4 tests

- [ ] **Step 2.5: Commit**

```bash
git add apps/api/src/notifications/notifications.controller.ts apps/api/src/notifications/notifications.controller.spec.ts
git commit -m "feat(notifications): add NotificationsController REST endpoints"
```

---

## Task 3: NotificationsGateway (WebSocket + Redis pub/sub)
Depends-on: 1

**Files:**
- Create: `src/notifications/notifications.gateway.ts`

- [ ] **Step 3.1: Install Socket.IO adapter**

```bash
cd apps/api
npm install --save @nestjs/websockets @nestjs/platform-socket.io socket.io
npm install --save-dev @types/socket.io
```

Configure Socket.IO adapter in `main.ts`:

```typescript
// In main.ts, add after app is created:
import { IoAdapter } from '@nestjs/platform-socket.io';
app.useWebSocketAdapter(new IoAdapter(app));
```

- [ ] **Step 3.2: Implement NotificationsGateway**

```typescript
// apps/api/src/notifications/notifications.gateway.ts
import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayInit,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Redis } from 'ioredis';

const NOTIFICATION_CHANNEL = 'notifications:new';

@WebSocketGateway({ namespace: '/notifications', cors: { origin: '*' } })
export class NotificationsGateway implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(NotificationsGateway.name);
  private subscriber: Redis;

  constructor(private readonly jwtService: JwtService) {}

  afterInit() {
    this.subscriber = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    this.subscriber.subscribe(NOTIFICATION_CHANNEL);
    this.subscriber.on('message', (_channel, message) => {
      try {
        const { userId, notification } = JSON.parse(message);
        this.server.to(`user:${userId}`).emit('notification', notification);
      } catch {
        this.logger.error('Failed to parse notification message');
      }
    });
    this.logger.log('NotificationsGateway initialized');
  }

  async handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth?.token ?? client.handshake.headers?.authorization?.replace('Bearer ', '');
      if (!token) throw new Error('No token');
      const payload = this.jwtService.verify<{ sub: string }>(token);
      client.join(`user:${payload.sub}`);
      client.data.userId = payload.sub;
      this.logger.debug(`Client connected: user ${payload.sub}`);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.debug(`Client disconnected: user ${client.data?.userId}`);
  }

  static publish(publisher: Redis, userId: string, notification: object) {
    return publisher.publish(NOTIFICATION_CHANNEL, JSON.stringify({ userId, notification }));
  }
}
```

- [ ] **Step 3.3: Wire NotificationsModule**

```typescript
// apps/api/src/notifications/notifications.module.ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '../prisma/prisma.module';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsGateway } from './notifications.gateway';

@Module({
  imports: [
    PrismaModule,
    JwtModule.register({}),
  ],
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationsGateway],
  exports: [NotificationsService],
})
export class NotificationsModule {}
```

Add `NotificationsModule` to `AppModule` imports.

- [ ] **Step 3.4: Run full unit test suite — no regressions**

```bash
cd apps/api && npm test
```

Expected: All tests pass.

- [ ] **Step 3.5: Manual smoke test (requires docker compose up)**

```bash
# Terminal 1
docker compose up -d
npm run start:dev

# Terminal 2 — connect via wscat
npx wscat -c "ws://localhost:3000/notifications" \
  --header "Authorization: Bearer <jwt_token_from_login>"
# Should connect without disconnect
# In another terminal, mark a notification read via REST
# WebSocket should emit 'notification' event
```

- [ ] **Step 3.6: Commit**

```bash
git add apps/api/src/notifications/notifications.gateway.ts apps/api/src/notifications/notifications.module.ts
git commit -m "feat(notifications): add WebSocket gateway with Redis pub/sub"
```

---

## Phase 6 Complete

- ✅ `NotificationsService` — paginated list, mark single/all read, delete, push (DB write)
- ✅ `NotificationsController` — `GET /notifications`, `PATCH /notifications/read-all`, `PATCH /notifications/:id/read`, `DELETE /notifications/:id`
- ✅ `NotificationsGateway` — Socket.IO at `/notifications`, JWT auth on handshake, Redis pub/sub for live push, user rooms
- ✅ All REST endpoints protected by `JwtAuthGuard`
- ✅ Unit tests: 8 tests across service + controller

**Next plan:** `2026-06-16-backend-api-phase7.md` — Reports & Export (raw SQL aggregations, CSV, PDF)
