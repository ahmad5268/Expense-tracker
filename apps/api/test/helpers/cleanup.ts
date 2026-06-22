import { PrismaService } from '../../src/prisma/prisma.service';

export async function cleanupTestUsers(
  prisma: PrismaService,
  where: { email: { contains: string } } | { email: { in: string[] } },
) {
  const users = await prisma.user.findMany({ where, select: { id: true } });
  if (users.length > 0) {
    const ids = users.map((u) => u.id);
    await prisma.workspace.deleteMany({ where: { ownerId: { in: ids } } });
  }
  await prisma.user.deleteMany({ where });
}
