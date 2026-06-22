import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { PrismaService } from '../src/prisma/prisma.service';
import { cleanupTestUsers } from './helpers/cleanup';

describe('Transactions (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let accessToken: string;
  let otherToken: string;
  let workspaceId: string;
  let categoryId: string;
  let transactionId: string;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    app.useGlobalInterceptors(new TransformInterceptor());
    await app.init();
    prisma = module.get(PrismaService);

    await cleanupTestUsers(prisma, { email: { contains: 'e2e-txns' } });

    // Register primary user
    const res = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-txns@test.com', password: 'Password123!', name: 'Txn User' });
    accessToken = res.body.data.accessToken;

    // Create workspace
    const wsRes = await request(app.getHttpServer())
      .post('/workspaces')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ name: 'Txn Test WS', currency: 'USD' });
    workspaceId = wsRes.body.data.id;

    // Get first category (expense)
    const catRes = await request(app.getHttpServer())
      .get(`/workspaces/${workspaceId}/categories`)
      .set('Authorization', `Bearer ${accessToken}`);
    categoryId = catRes.body.data[0].id;

    // Register a non-member user for 403 tests
    const otherRes = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-txns-other@test.com', password: 'Password123!', name: 'Other User' });
    otherToken = otherRes.body.data.accessToken;
  });

  afterAll(async () => {
    await cleanupTestUsers(prisma, { email: { contains: 'e2e-txns' } });
    await app.close();
  });

  describe('POST /workspaces/:workspaceId/transactions', () => {
    it('creates EXPENSE transaction with integer amount', async () => {
      const res = await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/transactions`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 5000, type: 'EXPENSE', categoryId, date: '2026-06-01', description: 'Lunch' })
        .expect(201);

      expect(res.body.data.amount).toBe(5000);
      expect(res.body.data.type).toBe('EXPENSE');
      expect(res.body.data).toHaveProperty('id');
      transactionId = res.body.data.id;
    });

    it('creates INCOME transaction with integer amount', async () => {
      // Find an income category
      const catRes = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`);
      const incomeCategory = catRes.body.data.find((c: any) => c.type === 'INCOME');
      const incomeCategoryId = incomeCategory ? incomeCategory.id : categoryId;

      const res = await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/transactions`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 200000, type: 'INCOME', categoryId: incomeCategoryId, date: '2026-06-01' })
        .expect(201);

      expect(res.body.data.amount).toBe(200000);
      expect(res.body.data.type).toBe('INCOME');
    });

    it('returns 400 when amount is missing', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/transactions`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ type: 'EXPENSE', categoryId, date: '2026-06-01' })
        .expect(400);
    });

    it('returns 400 when type is invalid', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/transactions`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 5000, type: 'TRANSFER', categoryId, date: '2026-06-01' })
        .expect(400);
    });

    it('returns 400 when date is missing', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/transactions`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 5000, type: 'EXPENSE', categoryId })
        .expect(400);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/transactions`)
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ amount: 5000, type: 'EXPENSE', categoryId, date: '2026-06-01' })
        .expect(403);
    });

    it('returns 401 without token', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/transactions`)
        .send({ amount: 5000, type: 'EXPENSE', categoryId, date: '2026-06-01' })
        .expect(401);
    });
  });

  describe('GET /workspaces/:workspaceId/transactions', () => {
    it('returns paginated result with data array and meta', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/transactions?page=1&limit=20`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data.data)).toBe(true);
      expect(res.body.data).toHaveProperty('meta');
      expect(res.body.data.meta).toHaveProperty('total');
    });

    it('filters by type=EXPENSE and returns only expense transactions', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/transactions?page=1&limit=20&type=EXPENSE`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data.data)).toBe(true);
      expect(res.body.data.data.length).toBeGreaterThanOrEqual(1);
      res.body.data.data.forEach((tx: any) => {
        expect(tx.type).toBe('EXPENSE');
      });
    });

    it('meta.total is accurate', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/transactions?page=1&limit=20`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(typeof res.body.data.meta.total).toBe('number');
      expect(res.body.data.meta.total).toBeGreaterThanOrEqual(res.body.data.data.length);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/transactions?page=1&limit=20`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });
  });

  describe('PUT /workspaces/:workspaceId/transactions/:transactionId', () => {
    it('updates amount and description', async () => {
      const res = await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/transactions/${transactionId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 7500, description: 'Updated lunch' })
        .expect(200);

      expect(res.body.data.amount).toBe(7500);
      expect(res.body.data.description).toBe('Updated lunch');
      expect(res.body.data.id).toBe(transactionId);
    });

    it('returns 404 for non-existent transaction', async () => {
      await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/transactions/00000000-0000-0000-0000-000000000000`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ amount: 1000 })
        .expect(404);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/transactions/${transactionId}`)
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ amount: 1000 })
        .expect(403);
    });
  });

  describe('DELETE /workspaces/:workspaceId/transactions/:transactionId', () => {
    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .delete(`/workspaces/${workspaceId}/transactions/${transactionId}`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });

    it('deletes transaction and returns 204', async () => {
      await request(app.getHttpServer())
        .delete(`/workspaces/${workspaceId}/transactions/${transactionId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(204);
    });

    it('subsequent GET omits the deleted transaction', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/transactions?page=1&limit=20`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      const ids = res.body.data.data.map((tx: any) => tx.id);
      expect(ids).not.toContain(transactionId);
    });
  });
});
