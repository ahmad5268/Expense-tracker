import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { PrismaService } from '../src/prisma/prisma.service';
import { cleanupTestUsers } from './helpers/cleanup';

describe('Recurring Rules (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let accessToken: string;
  let otherToken: string;
  let workspaceId: string;
  let categoryId: string;
  let ruleId: string;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    app.useGlobalInterceptors(new TransformInterceptor());
    await app.init();
    prisma = module.get(PrismaService);

    await cleanupTestUsers(prisma, { email: { contains: 'e2e-recurring' } });

    // Register primary user
    const res = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-recurring@test.com', password: 'Password123!', name: 'Recurring User' });
    accessToken = res.body.data.accessToken;

    // Create workspace
    const wsRes = await request(app.getHttpServer())
      .post('/workspaces')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ name: 'Recurring Test WS', currency: 'USD' });
    workspaceId = wsRes.body.data.id;

    // Get first category
    const catRes = await request(app.getHttpServer())
      .get(`/workspaces/${workspaceId}/categories`)
      .set('Authorization', `Bearer ${accessToken}`);
    categoryId = catRes.body.data[0].id;

    // Register a non-member user for 403 tests
    const otherRes = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-recurring-other@test.com', password: 'Password123!', name: 'Other User' });
    otherToken = otherRes.body.data.accessToken;
  });

  afterAll(async () => {
    await cleanupTestUsers(prisma, { email: { contains: 'e2e-recurring' } });
    await app.close();
  });

  describe('POST /workspaces/:workspaceId/recurring', () => {
    it('creates recurring rule with correct fields', async () => {
      const res = await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/recurring`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          amount: 150000,
          type: 'EXPENSE',
          categoryId,
          frequency: 'MONTHLY',
          startDate: '2026-01-01',
          description: 'Monthly rent',
        })
        .expect(201);

      expect(res.body.data).toHaveProperty('id');
      expect(res.body.data.amount).toBe(150000);
      expect(res.body.data.type).toBe('EXPENSE');
      expect(res.body.data.frequency).toBe('MONTHLY');
      expect(res.body.data.description).toBe('Monthly rent');
      ruleId = res.body.data.id;
    });

    it('returns 400 when frequency is invalid', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/recurring`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          amount: 5000,
          type: 'EXPENSE',
          categoryId,
          frequency: 'HOURLY',
          startDate: '2026-01-01',
        })
        .expect(400);
    });

    it('returns 400 when amount is missing', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/recurring`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          type: 'EXPENSE',
          categoryId,
          frequency: 'MONTHLY',
          startDate: '2026-01-01',
        })
        .expect(400);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/recurring`)
        .set('Authorization', `Bearer ${otherToken}`)
        .send({
          amount: 5000,
          type: 'EXPENSE',
          categoryId,
          frequency: 'MONTHLY',
          startDate: '2026-01-01',
        })
        .expect(403);
    });

    it('returns 401 without token', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/recurring`)
        .send({
          amount: 5000,
          type: 'EXPENSE',
          categoryId,
          frequency: 'MONTHLY',
          startDate: '2026-01-01',
        })
        .expect(401);
    });
  });

  describe('GET /workspaces/:workspaceId/recurring', () => {
    it('returns array including the created rule', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/recurring`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);

      const ids = res.body.data.map((r: any) => r.id);
      expect(ids).toContain(ruleId);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/recurring`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });
  });

  describe('PUT /workspaces/:workspaceId/recurring/:ruleId', () => {
    it('updates amount', async () => {
      const res = await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/recurring/${ruleId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 200000 })
        .expect(200);

      expect(res.body.data.amount).toBe(200000);
      expect(res.body.data.id).toBe(ruleId);
    });

    it('returns 404 for non-existent rule', async () => {
      await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/recurring/00000000-0000-0000-0000-000000000000`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 5000 })
        .expect(404);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/recurring/${ruleId}`)
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ amount: 5000 })
        .expect(403);
    });
  });

  describe('DELETE /workspaces/:workspaceId/recurring/:ruleId', () => {
    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .delete(`/workspaces/${workspaceId}/recurring/${ruleId}`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });

    it('deletes rule and returns 204', async () => {
      await request(app.getHttpServer())
        .delete(`/workspaces/${workspaceId}/recurring/${ruleId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(204);
    });

    it('deleted rule is no longer in the list', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/recurring`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      const ids = res.body.data.map((r: any) => r.id);
      expect(ids).not.toContain(ruleId);
    });
  });
});
