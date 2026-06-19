import { Test } from '@nestjs/testing';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';

const mockService = {
  findAll: jest.fn(),
  markRead: jest.fn(),
  markAllRead: jest.fn(),
  remove: jest.fn(),
};

const user = { sub: 'u1', email: 'test@example.com' };

describe('NotificationsController', () => {
  let controller: NotificationsController;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      controllers: [NotificationsController],
      providers: [{ provide: NotificationsService, useValue: mockService }],
    }).compile();
    controller = module.get(NotificationsController);
  });

  it('GET / calls findAll with userId', async () => {
    mockService.findAll.mockResolvedValue({ data: [], total: 0, page: 1, limit: 20, totalPages: 0 });
    await controller.findAll(user, {});
    expect(mockService.findAll).toHaveBeenCalledWith('u1', {});
  });

  it('PATCH /:id/read calls markRead', async () => {
    mockService.markRead.mockResolvedValue({ id: 'n1', isRead: true });
    await controller.markRead(user, 'n1');
    expect(mockService.markRead).toHaveBeenCalledWith('u1', 'n1');
  });

  it('PATCH /read-all calls markAllRead', async () => {
    mockService.markAllRead.mockResolvedValue({ count: 3 });
    await controller.markAllRead(user);
    expect(mockService.markAllRead).toHaveBeenCalledWith('u1');
  });

  it('DELETE /:id calls remove', async () => {
    mockService.remove.mockResolvedValue({ id: 'n1' });
    await controller.remove(user, 'n1');
    expect(mockService.remove).toHaveBeenCalledWith('u1', 'n1');
  });
});
