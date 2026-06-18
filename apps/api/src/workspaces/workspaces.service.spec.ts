import { Test } from '@nestjs/testing';
import { WorkspacesService } from './workspaces.service';
import { PrismaService } from '../prisma/prisma.service';

jest.mock('@sendgrid/mail', () => ({
  default: { setApiKey: jest.fn(), send: jest.fn().mockResolvedValue([]) },
}));

const mockPrisma = {
  workspace: { create: jest.fn(), findMany: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
  workspaceMember: { create: jest.fn() },
  category: { createMany: jest.fn() },
  workspaceInvite: {
    create: jest.fn(),
    findFirst: jest.fn(),
    findUnique: jest.fn(),
    update: jest.fn(),
  },
  $transaction: jest.fn(),
};

describe('WorkspacesService', () => {
  let service: WorkspacesService;

  beforeEach(async () => {
    jest.clearAllMocks();
    const module = await Test.createTestingModule({
      providers: [WorkspacesService, { provide: PrismaService, useValue: mockPrisma }],
    }).compile();
    service = module.get(WorkspacesService);
  });

  it('create seeds default categories', async () => {
    mockPrisma.$transaction.mockImplementation(async (cb: Function) => cb(mockPrisma));
    mockPrisma.workspace.create.mockResolvedValue({ id: 'w1', name: 'Test', currency: 'USD', ownerId: 'u1' });
    mockPrisma.workspaceMember.create.mockResolvedValue({});
    mockPrisma.category.createMany.mockResolvedValue({ count: 14 });

    await service.create('u1', { name: 'Test', currency: 'USD' });

    expect(mockPrisma.category.createMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.arrayContaining([expect.objectContaining({ name: 'Housing' })]),
      }),
    );
  });

  it('findAll returns user workspaces', async () => {
    mockPrisma.workspace.findMany.mockResolvedValue([{ id: 'w1' }]);
    const result = await service.findAll('u1');
    expect(result).toHaveLength(1);
  });

  it('invite sends email to the invited address', async () => {
    mockPrisma.workspaceInvite.findFirst.mockResolvedValue(null);
    mockPrisma.workspace.findUnique.mockResolvedValue({
      id: 'w1',
      name: 'Family Budget',
      currency: 'USD',
      ownerId: 'u1',
    });
    mockPrisma.workspaceInvite.create.mockResolvedValue({
      id: 'inv1',
      token: 'abc123',
      workspaceId: 'w1',
      invitedEmail: 'bob@example.com',
    });

    await service.invite('w1', 'u1', 'bob@example.com');

    const sgMail = (await import('@sendgrid/mail')).default;
    expect(sgMail.send).toHaveBeenCalledWith(
      expect.objectContaining({ to: 'bob@example.com' }),
    );
  });
});
