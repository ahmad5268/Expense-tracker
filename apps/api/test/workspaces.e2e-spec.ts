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
