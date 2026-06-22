import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { PrismaService } from '../src/prisma/prisma.service';
import { cleanupTestUsers } from './helpers/cleanup';

describe('Notifications (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let accessToken: string;

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

    await cleanupTestUsers(prisma, { email: { contains: 'e2e-notif' } });

    // Register a fresh user for notification tests
    const regRes = await request(app.getHttpServer())
      .post('/auth/register')
      .send({ email: 'e2e-notif@test.com', password: 'Password123!', name: 'Notif User' });
    accessToken = regRes.body.data.accessToken;
  });

  afterAll(async () => {
    await cleanupTestUsers(prisma, { email: { contains: 'e2e-notif' } });
    await app.close();
  });

  describe('GET /notifications', () => {
    it('returns array (empty for new user) — body.data is array', async () => {
      const res = await request(app.getHttpServer())
        .get('/notifications')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);

      expect(res.body).toHaveProperty('data');
      expect(Array.isArray(res.body.data.data)).toBe(true);
    });

    it('returns 401 without token', async () => {
      await request(app.getHttpServer())
        .get('/notifications')
        .expect(401);
    });
  });

  describe('PATCH /notifications/read-all', () => {
    it('returns 200 with mark-all-read response', async () => {
      await request(app.getHttpServer())
        .patch('/notifications/read-all')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(200);
    });

    it('returns 401 without token', async () => {
      await request(app.getHttpServer())
        .patch('/notifications/read-all')
        .expect(401);
    });
  });

  describe('DELETE /notifications/:id', () => {
    it('returns 404 for non-existent notification id (random UUID)', async () => {
      await request(app.getHttpServer())
        .delete('/notifications/00000000-0000-0000-0000-000000000000')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(404);
    });

    it('returns 401 without token', async () => {
      await request(app.getHttpServer())
        .delete('/notifications/00000000-0000-0000-0000-000000000000')
        .expect(401);
    });
  });
});
