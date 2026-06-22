import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { PrismaService } from '../src/prisma/prisma.service';
import { cleanupTestUsers } from './helpers/cleanup';

describe('Categories (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let accessToken: string;
  let otherToken: string;
  let workspaceId: string;
  let customCategoryId: string;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new GlobalExceptionFilter());
    app.useGlobalInterceptors(new TransformInterceptor());
    await app.init();
    prisma = module.get(PrismaService);

    await cleanupTestUsers(prisma, { email: { contains: 'e2e-cats' } });

    // Register primary user
    const res = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-cats@test.com', password: 'Password123!', name: 'Cat User' });
    accessToken = res.body.data.accessToken;

    // Create workspace (seeds 14 default categories)
    const wsRes = await request(app.getHttpServer())
      .post('/workspaces')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ name: 'Categories Test WS', currency: 'USD' });
    workspaceId = wsRes.body.data.id;

    // Register a non-member user for 403 tests
    const otherRes = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-cats-other@test.com', password: 'Password123!', name: 'Other User' });
    otherToken = otherRes.body.data.accessToken;
  });

  afterAll(async () => {
    await cleanupTestUsers(prisma, { email: { contains: 'e2e-cats' } });
    await app.close();
  });

  describe('GET /workspaces/:workspaceId/categories', () => {
    it('returns 14 seeded categories on fresh workspace', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(14);
    });

    it('all categories have type field (EXPENSE or INCOME)', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      res.body.data.forEach((cat: any) => {
        expect(['EXPENSE', 'INCOME']).toContain(cat.type);
      });
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/categories`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });
  });

  describe('POST /workspaces/:workspaceId/categories', () => {
    it('creates custom category', async () => {
      const res = await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ name: 'My Custom Category', type: 'EXPENSE', icon: 'star', color: '#FF5733' })
        .expect(201);

      expect(res.body.data).toHaveProperty('id');
      expect(res.body.data.name).toBe('My Custom Category');
      expect(res.body.data.type).toBe('EXPENSE');
      customCategoryId = res.body.data.id;
    });

    it('returns 400 when name is empty', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ name: '', type: 'EXPENSE' })
        .expect(400);
    });

    it('returns 400 when type is missing', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ name: 'No Type Category' })
        .expect(400);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .post(`/workspaces/${workspaceId}/categories`)
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ name: 'Hacker Category', type: 'EXPENSE' })
        .expect(403);
    });
  });

  describe('PUT /workspaces/:workspaceId/categories/:categoryId', () => {
    it('updates name and color', async () => {
      const res = await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/categories/${customCategoryId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ name: 'Updated Category', color: '#123456' })
        .expect(200);

      expect(res.body.data.name).toBe('Updated Category');
      expect(res.body.data.color).toBe('#123456');
      expect(res.body.data.id).toBe(customCategoryId);
    });

    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .put(`/workspaces/${workspaceId}/categories/${customCategoryId}`)
        .set('Authorization', `Bearer ${otherToken}`)
        .send({ name: 'Hacked Name' })
        .expect(403);
    });
  });

  describe('DELETE /workspaces/:workspaceId/categories/:categoryId', () => {
    it('returns 403 for non-member', async () => {
      await request(app.getHttpServer())
        .delete(`/workspaces/${workspaceId}/categories/${customCategoryId}`)
        .set('Authorization', `Bearer ${otherToken}`)
        .expect(403);
    });

    it('deletes the custom category and returns 204', async () => {
      await request(app.getHttpServer())
        .delete(`/workspaces/${workspaceId}/categories/${customCategoryId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(204);
    });

    it('deleted category is no longer in the list', async () => {
      const res = await request(app.getHttpServer())
        .get(`/workspaces/${workspaceId}/categories`)
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      const ids = res.body.data.map((c: any) => c.id);
      expect(ids).not.toContain(customCategoryId);
    });
  });
});
