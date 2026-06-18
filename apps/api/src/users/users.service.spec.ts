import { Test } from '@nestjs/testing';
import { UsersService } from './users.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

const mockPrisma = {
  user: {
    findUnique: jest.fn(),
    update: jest.fn(),
  },
};

describe('UsersService', () => {
  let service: UsersService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [UsersService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get(UsersService);
  });

  describe('findMe', () => {
    it('returns user when found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com', name: 'Ali' });
      const result = await service.findMe('u1');
      expect(result).toMatchObject({ id: 'u1', email: 'a@b.com' });
    });

    it('throws NotFoundException when user not found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);
      await expect(service.findMe('bad')).rejects.toThrow(NotFoundException);
    });
  });

  describe('updateMe', () => {
    it('updates and returns user', async () => {
      mockPrisma.user.update.mockResolvedValue({ id: 'u1', name: 'New Name' });
      const result = await service.updateMe('u1', { name: 'New Name' });
      expect(result.name).toBe('New Name');
    });
  });
});
