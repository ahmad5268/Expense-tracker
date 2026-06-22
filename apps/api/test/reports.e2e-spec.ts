import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { PrismaService } from '../src/prisma/prisma.service';
import { cleanupTestUsers } from './helpers/cleanup';

describe('Reports (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let accessToken: string;
  let nonMemberToken: string;
  let workspaceId: string;
  let categoryId: string;

  const year = new Date().getFullYear();
  const month = new Date().getMonth() + 1;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    app.useGlobalInterceptors(new TransformInterceptor());
    await app.init();

    prisma = module.get(PrismaService);

    await cleanupTestUsers(prisma, { email: { contains: 'e2e-reports' } });

    // Register primary user
    const regRes = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-reports@test.com', password: 'Password123!', name: 'Reports User' });
    accessToken = regRes.body.data.accessToken;

    // Register non-member user for 403 tests
    const nonMemberRes = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-reports-other@test.com', password: 'Password123!', name: 'Other User' });
    nonMemberToken = nonMemberRes.body.data.accessToken;

    // Create workspace
    const wsRes = await request(app.getHttpServer())
      .post('/workspaces')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ name: 'Reports Workspace', currency: 'USD' });
    workspaceId = wsRes.body.data.id;

    // Fetch seeded categories and grab the first one
    const catRes = await request(app.getHttpServer())
      .get(`/workspaces/${workspaceId}/categories`)
      .set('Authorization', `Bearer ${accessToken}`);
    categoryId = catRes.body.data[0].id;

    // Insert 3 transactions: 2 EXPENSE + 1 INCOME for current year/month
    const dateStr = `${year}-${String(month).padStart(2, '0')}-15`;

    await request(app.getHttpServer())
      .post(`/workspaces/${workspaceId}/transactions`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ categoryId, amount: 15000, type: 'EXPENSE', date: dateStr, description: 'Groceries' });

    await request(app.getHttpServer())
      .post(`/workspaces/${workspaceId}/transactions`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ categoryId, amount: 8000, type: 'EXPENSE', date: dateStr, description: 'Transport' });

    await request(app.getHttpServer())
      .post(`/workspaces/${workspaceId}/transactions`)
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ categoryId, amount: 50000, type: 'INCOME', date: dateStr, description: 'Salary' });
  });

  afterAll(async () => {
    await cleanupTestUsers(prisma, { email: { contains: 'e2e-reports' } });
    await app.close();
  });

  describe('GET /workspaces/:workspaceId/reports/summary', () => {
    it('returns totalIncome, totalExpense, net as numbers', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/summary?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body.data).toHaveProperty('totalIncome');
      expect(res.body.data).toHaveProperty('totalExpense');
      expect(res.body.data).toHaveProperty('net');
      expect(typeof res.body.data.totalIncome).toBe('number');
      expect(typeof res.body.data.totalExpense).toBe('number');
      expect(typeof res.body.data.net).toBe('number');
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/summary?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${nonMemberToken}`)
        .expect(403);
    });
  });

  describe('GET /workspaces/:workspaceId/reports/by-category', () => {
    it('returns array', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/by-category?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/by-category?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${nonMemberToken}`)
        .expect(403);
    });
  });

  describe('GET /workspaces/:workspaceId/reports/trends', () => {
    it('returns array of trend points', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/trends?year=${year}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/trends?year=${year}`)
        .set('Authorization', `Bearer ${nonMemberToken}`)
        .expect(403);
    });
  });

  describe('GET /workspaces/:workspaceId/reports/budget-vs-actual', () => {
    it('returns array', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/budget-vs-actual?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/budget-vs-actual?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${nonMemberToken}`)
        .expect(403);
    });
  });

  describe('GET /workspaces/:workspaceId/reports/year-over-year', () => {
    it('returns array', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/year-over-year`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/year-over-year`)
        .set('Authorization', `Bearer ${nonMemberToken}`)
        .expect(403);
    });
  });

  describe('GET /workspaces/:workspaceId/reports/heatmap', () => {
    it('returns array', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/heatmap?year=${year}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/heatmap?year=${year}`)
        .set('Authorization', `Bearer ${nonMemberToken}`)
        .expect(403);
    });
  });

  describe('GET /workspaces/:workspaceId/reports/export/csv', () => {
    it('Content-Type contains text/csv', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/export/csv?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.headers['content-type']).toMatch(/text\/csv/);
    });

    it('response body starts with a header row (contains Date or Amount)', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/export/csv?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .buffer(true)
        .parse((res, callback) => {
          const chunks: Buffer[] = [];
          res.on('data', (chunk: Buffer) => chunks.push(chunk));
          res.on('end', () => callback(null, Buffer.concat(chunks).toString('utf-8')));
        });

      const body: string = res.body as string;
      expect(body).toMatch(/Date|Amount/i);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/export/csv?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${nonMemberToken}`)
        .expect(403);
    });
  });

  describe('GET /workspaces/:workspaceId/reports/export/pdf', () => {
    it('Content-Type is application/pdf', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/export/pdf?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.headers['content-type']).toMatch(/application\/pdf/);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/reports/export/pdf?year=${year}&month=${month}`)
        .set('Authorization', `Bearer ${nonMemberToken}`)
        .expect(403);
    });
  });
});
