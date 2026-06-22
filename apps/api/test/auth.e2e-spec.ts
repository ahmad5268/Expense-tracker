import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { GlobalExceptionFilter } from '../src/common/filters/http-exception.filter';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Auth (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

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

    // Clean up any leftover test users from previous interrupted runs
    await prisma.user.deleteMany({ where: { email: { contains: 'e2e-auth@' } } });
    await prisma.user.deleteMany({ where: { email: { in: ['e2e-auth-me@test.com', 'e2e-auth-rotation@test.com'] } } });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { contains: 'e2e-auth@' } } });
    await prisma.user.deleteMany({ where: { email: { in: ['e2e-auth-me@test.com', 'e2e-auth-rotation@test.com'] } } });
    await app.close();
  });

  const testEmail = 'e2e-auth@test.com';
  const testPassword = 'Password123!';
  let accessToken: string;
  let refreshToken: string;

  describe('POST /auth/register', () => {
    it('creates user and returns token pair', async () => {
      const res = await request(app.getHttpServer())
        .post('/auth/register')
        .send({ email: testEmail, password: testPassword, name: 'E2E User' })
        .expect(201);

      expect(res.body.data).toHaveProperty('accessToken');
      expect(res.body.data).toHaveProperty('refreshToken');
      accessToken = res.body.data.accessToken;
      refreshToken = res.body.data.refreshToken;
    });

    it('returns 409 when email already registered', async () => {
      await request(app.getHttpServer())
        .post('/auth/register')
        .send({ email: testEmail, password: testPassword, name: 'Dup' })
        .expect(409);
    });

    it('returns 400 when email is invalid', async () => {
      await request(app.getHttpServer())
        .post('/auth/register')
        .send({ email: 'not-an-email', password: testPassword, name: 'Bad' })
        .expect(400);
    });

    it('returns 400 when password is too short', async () => {
      await request(app.getHttpServer())
        .post('/auth/register')
        .send({ email: 'new@test.com', password: 'short', name: 'Bad' })
        .expect(400);
    });
  });

  describe('POST /auth/login', () => {
    it('returns token pair on valid credentials', async () => {
      const res = await request(app.getHttpServer())
        .post('/auth/login')
        .send({ email: testEmail, password: testPassword })
        .expect(200);

      expect(res.body.data).toHaveProperty('accessToken');
      expect(res.body.data).toHaveProperty('refreshToken');
      // Update shared tokens — login rotates the refresh token in the DB
      accessToken = res.body.data.accessToken;
      refreshToken = res.body.data.refreshToken;
    });

    it('returns 401 on wrong password', async () => {
      await request(app.getHttpServer())
        .post('/auth/login')
        .send({ email: testEmail, password: 'wrongpassword' })
        .expect(401);
    });

    it('returns 401 on unknown email', async () => {
      await request(app.getHttpServer())
        .post('/auth/login')
        .send({ email: 'nobody@test.com', password: testPassword })
        .expect(401);
    });
  });

  describe('POST /auth/refresh', () => {
    it('returns new token pair with valid refresh token', async () => {
      const res = await request(app.getHttpServer())
        .post('/auth/refresh')
        .set('Authorization', `Bearer ${refreshToken}`)
        .expect(200);

      expect(res.body.data).toHaveProperty('accessToken');
      expect(res.body.data).toHaveProperty('refreshToken');
      accessToken = res.body.data.accessToken;
      refreshToken = res.body.data.refreshToken;
    });

    it('returns 401 with invalid refresh token', async () => {
      await request(app.getHttpServer())
        .post('/auth/refresh')
        .set('Authorization', 'Bearer invalidtoken')
        .expect(401);
    });
  });

  describe('POST /auth/logout', () => {
    it('returns 204 and invalidates the refresh token', async () => {
      await request(app.getHttpServer())
        .post('/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .expect(204);

      await request(app.getHttpServer())
        .post('/auth/refresh')
        .set('Authorization', `Bearer ${refreshToken}`)
        .expect(401);
    });

    it('returns 401 without access token', async () => {
      await request(app.getHttpServer())
        .post('/auth/logout')
        .expect(401);
    });
  });

  describe('POST /auth/forgot-password', () => {
    it('returns 204 for known email', async () => {
      await request(app.getHttpServer())
        .post('/auth/forgot-password')
        .send({ email: testEmail })
        .expect(204);
    });

    it('returns 204 for unknown email (does not reveal non-existence)', async () => {
      await request(app.getHttpServer())
        .post('/auth/forgot-password')
        .send({ email: 'nobody@nowhere.com' })
        .expect(204);
    });
  });

  describe('GET /auth/me', () => {
    it('returns user profile with valid access token', async () => {
      const regRes = await request(app.getHttpServer())
        .post('/auth/register')
        .send({ email: 'e2e-auth-me@test.com', password: 'Password123!', name: 'Me Test' });
      const token = regRes.body.data.accessToken;

      const res = await request(app.getHttpServer())
        .get('/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.data).toHaveProperty('id');
      expect(res.body.data).toHaveProperty('email', 'e2e-auth-me@test.com');
      expect(res.body.data).toHaveProperty('name');
    });

    it('returns 401 without token', async () => {
      await request(app.getHttpServer()).get('/auth/me').expect(401);
    });
  });

  describe('Refresh token rotation', () => {
    it('old refresh token is rejected after a single use', async () => {
      const regRes = await request(app.getHttpServer())
        .post('/auth/register')
        .send({ email: 'e2e-auth-rotation@test.com', password: 'Password123!', name: 'Rotation Test' });
      const oldRefreshToken = regRes.body.data.refreshToken;

      // Use it once
      const firstRefresh = await request(app.getHttpServer())
        .post('/auth/refresh')
        .set('Authorization', `Bearer ${oldRefreshToken}`)
        .expect(200);
      expect(firstRefresh.body.data).toHaveProperty('accessToken');

      // Try to use the OLD token again — must fail
      await request(app.getHttpServer())
        .post('/auth/refresh')
        .set('Authorization', `Bearer ${oldRefreshToken}`)
        .expect(401);
    });
  });
});
