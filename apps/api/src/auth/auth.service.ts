import {
  Injectable, ConflictException, UnauthorizedException,
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

export interface AuthUser {
  id: string;
  email: string;
  name: string;
  avatarUrl: string | null;
  oauthProvider: string | null;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  user: AuthUser;
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

    return this.issueTokens(user);
  }

  async login(dto: LoginDto): Promise<TokenPair> {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user || !user.passwordHash) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    return this.issueTokens(user);
  }

  async getMe(userId: string): Promise<AuthUser> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      avatarUrl: user.avatarUrl,
      oauthProvider: user.oauthProvider,
    };
  }

  async refresh(payload: RefreshPayload): Promise<TokenPair> {
    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user?.refreshTokenHash) throw new UnauthorizedException('Refresh token invalid');

    const valid = await bcrypt.compare(payload.refreshToken, user.refreshTokenHash);
    if (!valid) throw new UnauthorizedException('Refresh token invalid');

    return this.issueTokens(user);
  }

  async logout(userId: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { refreshTokenHash: null },
    });
  }

  async upsertOAuthUser(profile: {
    email: string;
    name: string;
    oauthProvider: string;
    oauthId: string;
  }): Promise<TokenPair> {
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

    return this.issueTokens(user);
  }

  async forgotPassword(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return;

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
    const user = await this.prisma.user.findFirst({
      where: {
        passwordResetToken: token,
        passwordResetExpiry: { gt: new Date() },
      },
    });
    if (!user) throw new UnauthorizedException('Reset token is invalid or expired');

    const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        refreshTokenHash: null,
        passwordResetToken: null,
        passwordResetExpiry: null,
      },
    });
  }

  private async issueTokens(user: { id: string; email: string; name: string; avatarUrl: string | null; oauthProvider: string | null }): Promise<TokenPair> {
    const jwtPayload: JwtPayload = { sub: user.id, email: user.email };

    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(jwtPayload, { expiresIn: '15m' }),
      this.jwt.signAsync(jwtPayload, { expiresIn: '30d' }),
    ]);

    const refreshTokenHash = await bcrypt.hash(refreshToken, BCRYPT_ROUNDS);
    await this.prisma.user.update({
      where: { id: user.id },
      data: { refreshTokenHash },
    });

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        avatarUrl: user.avatarUrl,
        oauthProvider: user.oauthProvider,
      },
    };
  }
}
