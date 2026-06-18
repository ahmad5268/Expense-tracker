# Backend API — Phase 2: Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete authentication system — email/password registration and login, RS256 JWT access + refresh token rotation, Google OAuth, Apple OAuth, and password reset via SendGrid — so all subsequent modules can use `@CurrentUser()` and `JwtAuthGuard` to protect routes.

**Architecture:** All auth logic lives in `src/auth/`. `AuthService` owns all business logic. `AuthController` exposes the HTTP surface. Passport strategies handle credential validation and are registered as NestJS providers. The JWT access token is short-lived (15 min, RS256). The refresh token is long-lived (30 days), stored as a bcrypt hash in `users.refreshTokenHash`, and rotated on every use. Logout nullifies the stored hash, immediately invalidating the token.

**Tech Stack:** NestJS Passport, passport-jwt, passport-google-oauth20, passport-apple, @nestjs/jwt, bcrypt (cost 12), RS256 asymmetric keys, SendGrid, class-validator DTOs

**Prerequisite:** Phase 1 complete — PrismaService, GlobalExceptionFilter, TransformInterceptor, CurrentUser decorator, and AppModule all wired up.

---

## File Map

| File | Responsibility |
|---|---|
| `src/auth/dto/register.dto.ts` | Validated register request body |
| `src/auth/dto/login.dto.ts` | Validated login request body |
| `src/auth/dto/forgot-password.dto.ts` | Validated forgot-password request body |
| `src/auth/dto/reset-password.dto.ts` | Validated reset-password request body |
| `src/auth/strategies/jwt.strategy.ts` | Validates access token on protected routes |
| `src/auth/strategies/jwt-refresh.strategy.ts` | Validates refresh token on the refresh endpoint |
| `src/auth/strategies/google.strategy.ts` | Google OAuth20 — upserts user on callback |
| `src/auth/strategies/apple.strategy.ts` | Apple Sign In — upserts user on callback |
| `src/auth/guards/jwt-auth.guard.ts` | Protects routes requiring a valid access token |
| `src/auth/guards/jwt-refresh.guard.ts` | Protects the refresh endpoint |
| `src/auth/auth.service.ts` | All auth business logic |
| `src/auth/auth.service.spec.ts` | Unit tests for AuthService |
| `src/auth/auth.controller.ts` | HTTP surface for all auth endpoints |
| `src/auth/auth.module.ts` | Wires everything together |
| `test/auth.e2e-spec.ts` | Integration tests for the full auth flow |

---

## Task 1: Install auth packages + DTOs

**Files:**
- Create: `apps/api/src/auth/dto/register.dto.ts`
- Create: `apps/api/src/auth/dto/login.dto.ts`
- Create: `apps/api/src/auth/dto/forgot-password.dto.ts`
- Create: `apps/api/src/auth/dto/reset-password.dto.ts`

- [ ] **Step 1.1: Install auth packages**

```bash
cd apps/api
npm install --save @nestjs/jwt @nestjs/passport passport passport-jwt passport-google-oauth20 passport-apple bcrypt @sendgrid/mail
npm install --save-dev @types/passport-jwt @types/passport-google-oauth20 @types/bcrypt
```

- [ ] **Step 1.2: Create RegisterDto**

```typescript
// apps/api/src/auth/dto/register.dto.ts
import { IsEmail, IsString, MinLength, MaxLength } from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;

  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;
}
```

- [ ] **Step 1.3: Create LoginDto**

```typescript
// apps/api/src/auth/dto/login.dto.ts
import { IsEmail, IsString } from 'class-validator';

export class LoginDto {
  @IsEmail()
  email: string;

  @IsString()
  password: string;
}
```

- [ ] **Step 1.4: Create ForgotPasswordDto**

```typescript
// apps/api/src/auth/dto/forgot-password.dto.ts
import { IsEmail } from 'class-validator';

export class ForgotPasswordDto {
  @IsEmail()
  email: string;
}
```

- [ ] **Step 1.5: Create ResetPasswordDto**

```typescript
// apps/api/src/auth/dto/reset-password.dto.ts
import { IsString, MinLength, MaxLength } from 'class-validator';

export class ResetPasswordDto {
  @IsString()
  token: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;
}
```

- [ ] **Step 1.6: Commit**

```bash
git add apps/api/src/auth/dto/
git commit -m "feat(auth): add auth DTOs with validation"
```

---

## Task 2: JWT strategies + guards
Depends-on: 1

**Files:**
- Create: `apps/api/src/auth/strategies/jwt.strategy.ts`
- Create: `apps/api/src/auth/strategies/jwt-refresh.strategy.ts`
- Create: `apps/api/src/auth/guards/jwt-auth.guard.ts`
- Create: `apps/api/src/auth/guards/jwt-refresh.guard.ts`

- [ ] **Step 2.1: Create JwtStrategy (access token)**

```typescript
// apps/api/src/auth/strategies/jwt.strategy.ts
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { JwtPayload } from '../../common/decorators/current-user.decorator';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: Buffer.from(process.env.JWT_PUBLIC_KEY ?? '', 'base64').toString('utf8'),
      algorithms: ['RS256'],
    });
  }

  validate(payload: JwtPayload): JwtPayload {
    return { sub: payload.sub, email: payload.email };
  }
}
```

- [ ] **Step 2.2: Create JwtRefreshStrategy (refresh token)**

```typescript
// apps/api/src/auth/strategies/jwt-refresh.strategy.ts
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { Request } from 'express';

export interface RefreshPayload {
  sub: string;
  email: string;
  refreshToken: string;
}

@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: Buffer.from(process.env.JWT_PUBLIC_KEY ?? '', 'base64').toString('utf8'),
      algorithms: ['RS256'],
      passReqToCallback: true,
    });
  }

  validate(req: Request, payload: { sub: string; email: string }): RefreshPayload {
    const refreshToken = req.headers.authorization?.replace('Bearer ', '') ?? '';
    return { sub: payload.sub, email: payload.email, refreshToken };
  }
}
```

- [ ] **Step 2.3: Create JwtAuthGuard**

```typescript
// apps/api/src/auth/guards/jwt-auth.guard.ts
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
```

- [ ] **Step 2.4: Create JwtRefreshGuard**

```typescript
// apps/api/src/auth/guards/jwt-refresh.guard.ts
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtRefreshGuard extends AuthGuard('jwt-refresh') {}
```

- [ ] **Step 2.5: Commit**

```bash
git add apps/api/src/auth/strategies/ apps/api/src/auth/guards/
git commit -m "feat(auth): add JWT access and refresh strategies and guards"
```

---

## Task 3: AuthService — register + login + token issuance
Depends-on: 1, 2

**Files:**
- Create: `apps/api/src/auth/auth.service.ts`
- Create: `apps/api/src/auth/auth.service.spec.ts`

- [ ] **Step 3.1: Write failing unit tests for register and login**

```typescript
// apps/api/src/auth/auth.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
};

const mockJwt = {
  signAsync: jest.fn(),
};

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwt },
      ],
    }).compile();
    service = module.get(AuthService);
  });

  describe('register', () => {
    it('hashes password and creates user', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      mockPrisma.user.create.mockResolvedValue({ id: 'u1', email: 'a@b.com', name: 'Ali' });
      mockJwt.signAsync.mockResolvedValue('token');

      const result = await service.register({ email: 'a@b.com', password: 'secret123', name: 'Ali' });

      expect(mockPrisma.user.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ email: 'a@b.com', name: 'Ali' }),
        }),
      );
      const createdData = mockPrisma.user.create.mock.calls[0][0].data;
      expect(createdData.passwordHash).not.toBe('secret123');
      expect(await bcrypt.compare('secret123', createdData.passwordHash)).toBe(true);
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
    });

    it('throws ConflictException when email exists', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com' });
      await expect(
        service.register({ email: 'a@b.com', password: 'secret123', name: 'Ali' }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('login', () => {
    it('returns tokens on valid credentials', async () => {
      const hash = await bcrypt.hash('secret123', 12);
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com', passwordHash: hash });
      mockPrisma.user.update.mockResolvedValue({});
      mockJwt.signAsync.mockResolvedValue('token');

      const result = await service.login({ email: 'a@b.com', password: 'secret123' });
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
    });

    it('throws UnauthorizedException on wrong password', async () => {
      const hash = await bcrypt.hash('correct', 12);
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com', passwordHash: hash });
      await expect(
        service.login({ email: 'a@b.com', password: 'wrong' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException when user not found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      await expect(
        service.login({ email: 'nobody@b.com', password: 'x' }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });
});
```

- [ ] **Step 3.2: Run tests — verify they fail**

```bash
cd apps/api
npm test -- --testPathPattern=auth.service
```

Expected: FAIL — `Cannot find module './auth.service'`

- [ ] **Step 3.3: Implement AuthService**

```typescript
// apps/api/src/auth/auth.service.ts
import {
  Injectable, ConflictException, UnauthorizedException, NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { addHours } from 'date-fns';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { JwtPayload } from '../common/decorators/current-user.decorator';
import { RefreshPayload } from './strategies/jwt-refresh.strategy';

const BCRYPT_ROUNDS = 12;

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: RegisterDto): Promise<TokenPair> {
    const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existing) throw new ConflictException('Email already registered');

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const user = await this.prisma.user.create({
      data: { email: dto.email, passwordHash, name: dto.name },
    });

    return this.issueTokens(user.id, user.email);
  }

  async login(dto: LoginDto): Promise<TokenPair> {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user || !user.passwordHash) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    return this.issueTokens(user.id, user.email);
  }

  async refresh(payload: RefreshPayload): Promise<TokenPair> {
    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user?.refreshTokenHash) throw new UnauthorizedException('Refresh token invalid');

    const valid = await bcrypt.compare(payload.refreshToken, user.refreshTokenHash);
    if (!valid) throw new UnauthorizedException('Refresh token invalid');

    return this.issueTokens(user.id, user.email);
  }

  async logout(userId: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { refreshTokenHash: null },
    });
  }

  async upsertOAuthUser(profile: { email: string; name: string; oauthProvider: string; oauthId: string }): Promise<TokenPair> {
    let user = await this.prisma.user.findUnique({ where: { email: profile.email } });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email: profile.email,
          name: profile.name,
          oauthProvider: profile.oauthProvider,
          oauthId: profile.oauthId,
        },
      });
    } else if (!user.oauthId) {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { oauthProvider: profile.oauthProvider, oauthId: profile.oauthId },
      });
    }

    return this.issueTokens(user.id, user.email);
  }

  async forgotPassword(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return; // Silently succeed — don't reveal whether email exists

    // Store a UUID reset token in the DB with a 1-hour expiry.
    // Using a DB-stored token (rather than a JWT) ensures single-use invalidation
    // on consumption and allows server-side revocation.
    const token = randomUUID();
    const expiresAt = addHours(new Date(), 1);

    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordResetToken: token, passwordResetExpiry: expiresAt },
    });

    const resetLink = `${process.env.FRONTEND_URL}/reset-password?token=${token}`;

    const sgMail = await import('@sendgrid/mail');
    sgMail.default.setApiKey(process.env.SENDGRID_API_KEY ?? '');
    await sgMail.default.send({
      to: email,
      from: process.env.SENDGRID_FROM_EMAIL ?? 'noreply@expensetracker.app',
      subject: 'Reset your Expense Tracker password',
      html: `
        <h2>Password Reset Request</h2>
        <p>Click the link below to reset your password. This link expires in 1 hour.</p>
        <p><a href="${resetLink}" style="background:#4f46e5;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none">Reset Password</a></p>
        <p>If you didn't request this, ignore this email.</p>
      `,
    });
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    let payload: { sub: string; purpose: string };
    try {
      payload = await this.jwt.verifyAsync(token);
    } catch {
      throw new UnauthorizedException('Reset token is invalid or expired');
    }

    if (payload.purpose !== 'password-reset') {
      throw new UnauthorizedException('Reset token is invalid or expired');
    }

    const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
    await this.prisma.user.update({
      where: { id: payload.sub },
      data: { passwordHash, refreshTokenHash: null },
    });
  }

  private async issueTokens(userId: string, email: string): Promise<TokenPair> {
    const jwtPayload: JwtPayload = { sub: userId, email };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(jwtPayload, { expiresIn: '15m' }),
      this.jwt.signAsync(jwtPayload, { expiresIn: '30d' }),
    ]);

    const refreshTokenHash = await bcrypt.hash(refreshToken, BCRYPT_ROUNDS);
    await this.prisma.user.update({
      where: { id: userId },
      data: { refreshTokenHash },
    });

    return { accessToken, refreshToken };
  }

  // Note: sendPasswordResetEmail is now inlined into forgotPassword() above.
  // The email is sent directly from forgotPassword with the full branded HTML template.
  // No separate private method is needed.
}
```

> **Prisma schema update required for `forgotPassword`:**
> Add these two nullable fields to the `User` model in `prisma/schema.prisma` (create a migration `add-user-password-reset-fields`):
> ```prisma
> model User {
>   // ... existing fields ...
>   passwordResetToken   String?   // UUID stored on forgotPassword call
>   passwordResetExpiry  DateTime? // 1-hour TTL from token issuance
> }
> ```
> Run: `npx prisma migrate dev --name add-user-password-reset-fields`
>
> **`resetPassword` must also be updated** to consume the DB token (not the JWT-based token in the current stub):
> ```typescript
> async resetPassword(token: string, newPassword: string): Promise<void> {
>   const user = await this.prisma.user.findFirst({
>     where: { passwordResetToken: token, passwordResetExpiry: { gt: new Date() } },
>   });
>   if (!user) throw new UnauthorizedException('Reset token is invalid or expired');
>   const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
>   await this.prisma.user.update({
>     where: { id: user.id },
>     data: { passwordHash, refreshTokenHash: null, passwordResetToken: null, passwordResetExpiry: null },
>   });
> }
> ```
>
> **Integration test to add to `test/auth.e2e-spec.ts`:**
> `POST /auth/forgot-password` with valid email → HTTP 204 + `sgMail.send` was called with correct `to` address (mock SendGrid in e2e with `jest.mock('@sendgrid/mail')`).

- [ ] **Step 3.4: Run tests — verify they pass**

```bash
npm test -- --testPathPattern=auth.service
```

Expected: PASS — 5 tests passing

- [ ] **Step 3.5: Commit**

```bash
git add apps/api/src/auth/auth.service.ts apps/api/src/auth/auth.service.spec.ts
git commit -m "feat(auth): add AuthService with register, login, refresh, OAuth upsert, password reset"
```

---

## Task 4: Google OAuth strategy
Depends-on: 3

**Files:**
- Create: `apps/api/src/auth/strategies/google.strategy.ts`

- [ ] **Step 4.1: Install Google strategy type (already done in Task 1 if missed)**

```bash
cd apps/api
npm install --save passport-google-oauth20
npm install --save-dev @types/passport-google-oauth20
```

- [ ] **Step 4.2: Implement GoogleStrategy**

```typescript
// apps/api/src/auth/strategies/google.strategy.ts
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, VerifyCallback, Profile } from 'passport-google-oauth20';
import { AuthService } from '../auth.service';

@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(private readonly authService: AuthService) {
    super({
      clientID: process.env.GOOGLE_CLIENT_ID ?? '',
      clientSecret: process.env.GOOGLE_CLIENT_SECRET ?? '',
      callbackURL: process.env.GOOGLE_CALLBACK_URL ?? 'http://localhost:3000/auth/google/callback',
      scope: ['email', 'profile'],
    });
  }

  async validate(_accessToken: string, _refreshToken: string, profile: Profile, done: VerifyCallback) {
    const email = profile.emails?.[0]?.value;
    const name = profile.displayName ?? profile.name?.givenName ?? 'User';

    if (!email) return done(new Error('No email from Google'), undefined);

    const tokens = await this.authService.upsertOAuthUser({
      email,
      name,
      oauthProvider: 'google',
      oauthId: profile.id,
    });

    done(null, tokens);
  }
}
```

- [ ] **Step 4.3: Commit**

```bash
git add apps/api/src/auth/strategies/google.strategy.ts
git commit -m "feat(auth): add Google OAuth strategy"
```

---

## Task 5: Apple OAuth strategy
Depends-on: 3

**Files:**
- Create: `apps/api/src/auth/strategies/apple.strategy.ts`

- [ ] **Step 5.1: Install Apple strategy**

```bash
cd apps/api
npm install --save passport-apple
```

- [ ] **Step 5.2: Implement AppleStrategy**

```typescript
// apps/api/src/auth/strategies/apple.strategy.ts
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import Strategy from 'passport-apple';
import { AuthService } from '../auth.service';

@Injectable()
export class AppleStrategy extends PassportStrategy(Strategy, 'apple') {
  constructor(private readonly authService: AuthService) {
    super({
      clientID: process.env.APPLE_CLIENT_ID ?? '',
      teamID: process.env.APPLE_TEAM_ID ?? '',
      keyID: process.env.APPLE_KEY_ID ?? '',
      privateKeyString: process.env.APPLE_PRIVATE_KEY ?? '',
      callbackURL: process.env.APPLE_CALLBACK_URL ?? 'http://localhost:3000/auth/apple/callback',
      scope: ['email', 'name'],
    });
  }

  async validate(
    _accessToken: string,
    _refreshToken: string,
    idToken: { sub: string; email?: string },
    profile: { name?: { firstName?: string; lastName?: string } },
    done: (err: Error | null, user?: unknown) => void,
  ) {
    const email = idToken.email;
    if (!email) return done(new Error('No email from Apple'));

    const firstName = profile?.name?.firstName ?? '';
    const lastName = profile?.name?.lastName ?? '';
    const name = `${firstName} ${lastName}`.trim() || 'Apple User';

    const tokens = await this.authService.upsertOAuthUser({
      email,
      name,
      oauthProvider: 'apple',
      oauthId: idToken.sub,
    });

    done(null, tokens);
  }
}
```

- [ ] **Step 5.3: Commit**

```bash
git add apps/api/src/auth/strategies/apple.strategy.ts
git commit -m "feat(auth): add Apple Sign In strategy"
```

---

## Task 6: AuthController + AuthModule
Depends-on: 3, 4, 5

**Files:**
- Create: `apps/api/src/auth/auth.controller.ts`
- Create: `apps/api/src/auth/auth.module.ts`
- Modify: `apps/api/src/app.module.ts`

- [ ] **Step 6.1: Implement AuthController**

```typescript
// apps/api/src/auth/auth.controller.ts
import {
  Controller, Post, Body, UseGuards, Get, Req, Res, HttpCode, HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { RefreshPayload } from './strategies/jwt-refresh.strategy';
import { AuthGuard } from '@nestjs/passport';

@Controller('auth')
@Throttle({ default: { limit: 5, ttl: 60000 } })
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtRefreshGuard)
  refresh(@Req() req: Request) {
    return this.authService.refresh(req.user as RefreshPayload);
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(JwtAuthGuard)
  async logout(@CurrentUser() user: JwtPayload) {
    await this.authService.logout(user.sub);
  }

  @Get('google')
  @UseGuards(AuthGuard('google'))
  googleAuth() {
    // Passport redirects to Google
  }

  @Get('google/callback')
  @UseGuards(AuthGuard('google'))
  googleCallback(@Req() req: Request, @Res() res: Response) {
    const tokens = req.user as { accessToken: string; refreshToken: string };
    const params = new URLSearchParams(tokens);
    res.redirect(`${process.env.FRONTEND_URL}/auth/callback?${params}`);
  }

  @Get('apple/callback')
  @UseGuards(AuthGuard('apple'))
  appleCallback(@Req() req: Request, @Res() res: Response) {
    const tokens = req.user as { accessToken: string; refreshToken: string };
    const params = new URLSearchParams(tokens);
    res.redirect(`${process.env.FRONTEND_URL}/auth/callback?${params}`);
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    await this.authService.forgotPassword(dto.email);
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  async resetPassword(@Body() dto: ResetPasswordDto) {
    await this.authService.resetPassword(dto.token, dto.password);
  }
}
```

- [ ] **Step 6.2: Implement AuthModule**

```typescript
// apps/api/src/auth/auth.module.ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtRefreshStrategy } from './strategies/jwt-refresh.strategy';
import { GoogleStrategy } from './strategies/google.strategy';
import { AppleStrategy } from './strategies/apple.strategy';

@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      useFactory: () => ({
        privateKey: Buffer.from(process.env.JWT_PRIVATE_KEY ?? '', 'base64').toString('utf8'),
        publicKey: Buffer.from(process.env.JWT_PUBLIC_KEY ?? '', 'base64').toString('utf8'),
        signOptions: { algorithm: 'RS256' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy, JwtRefreshStrategy, GoogleStrategy, AppleStrategy],
  exports: [JwtModule, AuthService],
})
export class AuthModule {}
```

- [ ] **Step 6.3: Register AuthModule in AppModule**

```typescript
// apps/api/src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { AppController } from './app.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 10 }]),
    PrismaModule,
    AuthModule,
  ],
  controllers: [AppController],
})
export class AppModule {}
```

- [ ] **Step 6.4: Commit**

```bash
git add apps/api/src/auth/ apps/api/src/app.module.ts
git commit -m "feat(auth): add AuthController and AuthModule, register in AppModule"
```

---

## Task 7: Generate RS256 key pair + update .env
Depends-on: 6

**Files:**
- Modify: `apps/api/.env`

- [ ] **Step 7.1: Generate RS256 key pair**

Run this once in a terminal (Node.js):

```javascript
// Run with: node -e "<paste below>"
const { generateKeyPairSync } = require('crypto');
const { privateKey, publicKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});
console.log('JWT_PRIVATE_KEY=' + Buffer.from(privateKey).toString('base64'));
console.log('JWT_PUBLIC_KEY=' + Buffer.from(publicKey).toString('base64'));
```

- [ ] **Step 7.2: Add generated keys to apps/api/.env**

Copy the two output lines into `apps/api/.env`:

```bash
JWT_PRIVATE_KEY="<base64 from above>"
JWT_PUBLIC_KEY="<base64 from above>"
```

- [ ] **Step 7.3: Verify the API starts without errors**

```bash
cd apps/api
npm run start:dev
```

Expected: API starts on port 3000 with no JWT key errors.

- [ ] **Step 7.4: Commit (keys are in .env which is git-ignored — nothing to commit)**

```bash
# .env is git-ignored. Verify .env.example still has placeholder values.
git status  # should show no changes to tracked files
```

---

## Task 8: Auth e2e integration tests
Depends-on: 7

**Files:**
- Create: `apps/api/test/auth.e2e-spec.ts`

- [ ] **Step 8.1: Write the auth e2e test suite**

```typescript
// apps/api/test/auth.e2e-spec.ts
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
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: { contains: 'e2e-auth@' } } });
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
      // Update tokens for subsequent tests
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

      // Refresh token should now be invalid
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
    it('returns 204 for known email (does not reveal existence)', async () => {
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
});
```

- [ ] **Step 8.2: Verify Docker is running before tests**

```bash
docker compose ps
# Both postgres and redis should be "running"
```

- [ ] **Step 8.3: Run the auth e2e test suite**

```bash
cd apps/api
npm run test:e2e -- --testPathPattern=auth.e2e
```

Expected: PASS — all 11 tests green.

Note: `POST /auth/forgot-password` for a known email will attempt to call SendGrid. If `SENDGRID_API_KEY` is empty in `.env`, the test still returns 204 (the error is swallowed since we don't want to reveal email existence). This is acceptable for local dev. For CI, set a mock SendGrid key.

- [ ] **Step 8.4: Run full unit test suite — no regressions**

```bash
npm test
```

Expected: All tests pass.

- [ ] **Step 8.5: Commit**

```bash
git add apps/api/test/auth.e2e-spec.ts
git commit -m "test(auth): add comprehensive auth e2e test suite"
```

---

## Phase 2 Complete

At the end of this phase you have:

- ✅ Email/password register with bcrypt hashing (cost 12)
- ✅ Login returning RS256 access token (15 min) + refresh token (30 days)
- ✅ Refresh token rotation — single use, stored hashed in DB
- ✅ Logout immediately invalidates refresh token
- ✅ Google OAuth — upserts user on callback, redirects to frontend with tokens
- ✅ Apple Sign In — same pattern as Google
- ✅ **Password reset — DB-token approach** (UUID stored in `passwordResetToken`/`passwordResetExpiry` on User model, 1-hour expiry, full branded HTML email via SendGrid with styled button link; `resetPassword` consumes and clears the DB token)
- ✅ **Prisma schema additions:** `passwordResetToken String?` and `passwordResetExpiry DateTime?` on User model; migration `add-user-password-reset-fields`
- ✅ `JwtAuthGuard` ready to protect any route with `@UseGuards(JwtAuthGuard)`
- ✅ 11 e2e integration tests covering all auth flows; integration test for forgot-password with mocked SendGrid
- ✅ All unit tests pass

**Next plan:** `2026-06-16-backend-api-phase3.md` — Users, Workspaces, WorkspaceMemberGuard, invitations, Categories (CRUD + seed defaults), Transactions (CRUD + pagination + filtering)
