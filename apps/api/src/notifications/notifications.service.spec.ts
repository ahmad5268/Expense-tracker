import { Test } from '@nestjs/testing';
import { NotificationsService } from './notifications.service';
import { PrismaService } from '../prisma/prisma.service';

const mockPrisma = {
  notification: {
    findMany: jest.fn(),
    count: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
    delete: jest.fn(),
    create: jest.fn(),
  },
};

describe('NotificationsService', () => {
  let service: NotificationsService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();
    service = module.get(NotificationsService);
  });

  describe('findAll', () => {
    it('returns paginated notifications for user', async () => {
      mockPrisma.notification.findMany.mockResolvedValue([{ id: 'n1', userId: 'u1', isRead: false }]);
      mockPrisma.notification.count.mockResolvedValue(1);
      const result = await service.findAll('u1', { page: 1, limit: 20 });
      expect(result.data).toHaveLength(1);
      expect(result.total).toBe(1);
      expect(mockPrisma.notification.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { userId: 'u1' } }),
      );
    });
  });

  describe('markRead', () => {
    it('marks a single notification as read', async () => {
      mockPrisma.notification.update.mockResolvedValue({ id: 'n1', isRead: true });
      await service.markRead('u1', 'n1');
      expect(mockPrisma.notification.update).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: 'n1', userId: 'u1' } }),
      );
    });
  });

  describe('markAllRead', () => {
    it('marks all notifications as read for user', async () => {
      mockPrisma.notification.updateMany.mockResolvedValue({ count: 5 });
      await service.markAllRead('u1');
      expect(mockPrisma.notification.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { userId: 'u1', readAt: null } }),
      );
    });
  });

  describe('remove', () => {
    it('deletes a notification owned by the user', async () => {
      mockPrisma.notification.delete.mockResolvedValue({ id: 'n1' });
      await service.remove('u1', 'n1');
      expect(mockPrisma.notification.delete).toHaveBeenCalledWith(
        expect.objectContaining({ where: { id: 'n1', userId: 'u1' } }),
      );
    });
  });
});
