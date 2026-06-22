import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { PrismaService } from '../src/prisma/prisma.service';
import { cleanupTestUsers } from './helpers/cleanup';

describe('Budgets (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let accessToken: string;
  let otherToken: string;
  let workspaceId: string;
  let categoryId: string;
  let budgetId: string;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    app.useGlobalInterceptors(new TransformInterceptor());
    await app.init();
    prisma = module.get(PrismaService);

    await cleanupTestUsers(prisma, { email: { contains: 'e2e-budgets' } });

    // Register primary user
    const res = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-budgets@test.com', password: 'Password123!', name: 'Budget User' });
    accessToken = res.body.data.accessToken;

    // Create workspace
    const wsRes = await request(app.getHttpServer())
      .post('/workspaces')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ name: 'Budget Test WS', currency: 'USD' });
    workspaceId = wsRes.body.data.id;

    // Get first category
    const catRes = await request(app.getHttpServer())
      .get(`/workspaces/${workspaceId}/categories`)
      .set('Authorization', `Bearer ${accessToken}`);
    categoryId = catRes.body.data[0].id;

    // Register a non-member user for 403 tests
    const otherRes = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-budgets-other@test.com', password: 'Password123!', name: 'Other User' });
    otherToken = otherRes.body.data.accessToken;
  });

  afterAll(async () => {
    await cleanupTestUsers(prisma, { email: { contains: 'e2e-budgets' } });
    await app.close();
  });

  describe('POST /workspaces/:workspaceId/budgets', () => {
    it('creates budget with category and returns integer amount', async () => {
      const res = await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/budgets`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 10000, period: 'MONTHLY', categoryId, year: 2026, month: 6 })
        .expect(201);

      expect(res.body.data.amount).toBe(10000);
      expect(res.body.data).toHaveProperty('id');
      expect(res.body.data.period).toBe('MONTHLY');
      budgetId = res.body.data.id;
    });

    it('creates workspace-total budget without categoryId (YEARLY)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/budgets`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 120000, period: 'YEARLY', year: 2026 })
        .expect(201);

      expect(res.body.data.amount).toBe(120000);
      expect(res.body.data.categoryId).toBeNull();
      expect(res.body.data.period).toBe('YEARLY');
    });

    it('returns 400 when amount is missing', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/budgets`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ period: 'MONTHLY', year: 2026, month: 6 })
        .expect(400);
    });

    it('returns 400 when period is invalid', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/budgets`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 5000, period: 'DAILY', year: 2026 })
        .expect(400);
    });

    it('returns 400 when MONTHLY budget is missing month', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/budgets`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 5000, period: 'MONTHLY', year: 2026 })
        .expect(400);
    });

    it('returns 403 when caller is not a workspace member', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/budgets`)
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ amount: 10000, period: 'MONTHLY', year: 2026, month: 6 })
        .expect(403);
    });

    it('returns 401 without token', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/budgets`)
        .send({ amount: 10000, period: 'MONTHLY', year: 2026, month: 6 })
        .expect(401);
    });
  });

  describe('GET /workspaces/:workspaceId/budgets', () => {
    it('returns array of budgets', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/budgets`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/budgets`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });
  });

  describe('PUT /workspaces/:workspaceId/budgets/:budgetId', () => {
    it('updates amount', async () => {
      const res = await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/budgets/${budgetId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 20000 })
        .expect(200);

      expect(res.body.data.amount).toBe(20000);
      expect(res.body.data.id).toBe(budgetId);
    });

    it('returns 404 for non-existent budget', async () => {
      await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/budgets/00000000-0000-0000-0000-000000000000`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 5000 })
        .expect(404);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/budgets/${budgetId}`)
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ amount: 5000 })
        .expect(403);
    });
  });

  describe('DELETE /workspaces/:workspaceId/budgets/:budgetId', () => {
    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .delete(`/workspaces/${workspaceId}/budgets/${budgetId}`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });

    it('deletes budget and returns 204', async () => {
      await request(app.getHttpServer())
        .delete(`/workspaces/${workspaceId}/budgets/${budgetId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(204);
    });

    it('returns 404 when operating on the deleted budget', async () => {
      await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/budgets/${budgetId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 5000 })
        .expect(404);
    });
  });
});
