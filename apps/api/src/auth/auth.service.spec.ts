import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { createHash } from 'crypto';

const sha256 = (s: string) => createHash('sha256').update(s).digest('hex');

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    findUniqueOrThrow: jest.fn(),
    findFirst: jest.fn(),
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
      mockPrisma.user.create.mockResolvedValue({ id: 'u1', email: 'a@b.com', name: 'Ali', avatarUrl: null, oauthProvider: null });
      mockPrisma.user.update.mockResolvedValue({});
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
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com', name: 'Ali', avatarUrl: null, oauthProvider: null, passwordHash: hash });
      mockPrisma.user.update.mockResolvedValue({});
      mockJwt.signAsync.mockResolvedValue('token');

      const result = await service.login({ email: 'a@b.com', password: 'secret123' });
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      expect(result).toHaveProperty('user');
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

  describe('logout', () => {
    it('clears refreshTokenHash', async () => {
      mockPrisma.user.update.mockResolvedValue({});
      await service.logout('u1');
      expect(mockPrisma.user.update).toHaveBeenCalledWith({
        where: { id: 'u1' },
        data: { refreshTokenHash: null },
      });
    });
  });

  describe('resetPassword', () => {
    it('throws when token is invalid', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      await expect(service.resetPassword('bad-token', 'newpass123')).rejects.toThrow(UnauthorizedException);
    });

    it('updates passwordHash and clears reset fields on valid token', async () => {
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1' });
      mockPrisma.user.update.mockResolvedValue({});

      await service.resetPassword('valid-token', 'newpass123');

      const updateCall = mockPrisma.user.update.mock.calls[0][0];
      expect(updateCall.data.passwordResetToken).toBeNull();
      expect(updateCall.data.passwordResetExpiry).toBeNull();
      expect(updateCall.data.refreshTokenHash).toBeNull();
      expect(await bcrypt.compare('newpass123', updateCall.data.passwordHash)).toBe(true);
    });
  });

  describe('getMe', () => {
    it('returns user profile when found', async () => {
      mockPrisma.user.findUniqueOrThrow.mockResolvedValue({
        id: 'u1', email: 'a@b.com', name: 'Ali', avatarUrl: null, oauthProvider: null,
      });
      const result = await service.getMe('u1');
      expect(result).toHaveProperty('id', 'u1');
      expect(result).toHaveProperty('email', 'a@b.com');
    });

    it('throws when user does not exist', async () => {
      mockPrisma.user.findUniqueOrThrow.mockRejectedValue(new Error('Not found'));
      await expect(service.getMe('missing')).rejects.toThrow();
    });
  });

  describe('refresh (token rotation)', () => {
    it('returns new token pair and invalidates old token', async () => {
      const hash = await bcrypt.hash(sha256('rawRefreshToken'), 10);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'u1', email: 'a@b.com', name: 'Ali', avatarUrl: null, oauthProvider: null,
        refreshTokenHash: hash,
      });
      mockPrisma.user.update.mockResolvedValue({});
      mockJwt.signAsync.mockResolvedValue('newToken');

      const result = await service.refresh({ sub: 'u1', email: 'a@b.com', refreshToken: 'rawRefreshToken' });
      expect(result).toHaveProperty('accessToken');
      expect(result).toHaveProperty('refreshToken');
      // update is called to set new hash
      expect(mockPrisma.user.update).toHaveBeenCalled();
    });

    it('throws UnauthorizedException when token hash does not match', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'u1', email: 'a@b.com', name: 'Ali', avatarUrl: null, oauthProvider: null,
        refreshTokenHash: await bcrypt.hash('correct', 10),
      });

      await expect(
        service.refresh({ sub: 'u1', email: 'a@b.com', refreshToken: 'wrong' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException when user has no refresh token stored', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'u1', email: 'a@b.com', name: 'Ali', avatarUrl: null, oauthProvider: null,
        refreshTokenHash: null,
      });

      await expect(
        service.refresh({ sub: 'u1', email: 'a@b.com', refreshToken: 'any' }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });
});
