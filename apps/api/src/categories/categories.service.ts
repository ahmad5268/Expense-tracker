import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(workspaceId: string) {
    return this.prisma.category.findMany({
      where: { workspaceId },
      orderBy: [{ type: 'asc' }, { name: 'asc' }],
    });
  }

  create(workspaceId: string, dto: CreateCategoryDto) {
    return this.prisma.category.create({ data: { ...dto, workspaceId } });
  }

  async update(workspaceId: string, categoryId: string, dto: UpdateCategoryDto) {
    await this.assertOwnership(workspaceId, categoryId);
    return this.prisma.category.update({ where: { id: categoryId }, data: dto });
  }

  async remove(workspaceId: string, categoryId: string) {
    await this.assertOwnership(workspaceId, categoryId);
    await this.prisma.category.delete({ where: { id: categoryId } });
  }

  private async assertOwnership(workspaceId: string, categoryId: string) {
    const category = await this.prisma.category.findUnique({ where: { id: categoryId } });
    if (!category || category.workspaceId !== workspaceId) {
      throw new NotFoundException('Category not found');
    }
  }
}
