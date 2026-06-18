import { WorkspaceMemberGuard } from './workspace-member.guard';
import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

const mockPrisma = { workspaceMember: { findUnique: jest.fn() } };

function mockContext(userId: string, workspaceId: string): ExecutionContext {
  return {
    switchToHttp: () => ({
      getRequest: () => ({
        user: { sub: userId },
        params: { workspaceId },
      }),
    }),
  } as unknown as ExecutionContext;
}

describe('WorkspaceMemberGuard', () => {
  let guard: WorkspaceMemberGuard;

  beforeEach(() => {
    jest.clearAllMocks();
    guard = new WorkspaceMemberGuard(mockPrisma as unknown as PrismaService);
  });

  it('allows access when user is a member', async () => {
    mockPrisma.workspaceMember.findUnique.mockResolvedValue({ role: 'MEMBER' });
    const result = await guard.canActivate(mockContext('u1', 'w1'));
    expect(result).toBe(true);
  });

  it('throws ForbiddenException when user is not a member', async () => {
    mockPrisma.workspaceMember.findUnique.mockResolvedValue(null);
    await expect(guard.canActivate(mockContext('u1', 'w1'))).rejects.toThrow(ForbiddenException);
  });
});
