import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { BudgetsService } from './budgets.service';
import { CreateBudgetDto } from './dto/create-budget.dto';
import { UpdateBudgetDto } from './dto/update-budget.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../workspaces/guards/workspace-member.guard';

@Controller('workspaces/:workspaceId/budgets')
@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
export class BudgetsController {
  constructor(private readonly budgetsService: BudgetsService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.budgetsService.findAll(workspaceId);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateBudgetDto) {
    return this.budgetsService.create(workspaceId, dto);
  }

  @Put(':budgetId')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('budgetId') budgetId: string,
    @Body() dto: UpdateBudgetDto,
  ) {
    return this.budgetsService.update(workspaceId, budgetId, dto);
  }

  @Delete(':budgetId')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param('workspaceId') workspaceId: string, @Param('budgetId') budgetId: string) {
    return this.budgetsService.remove(workspaceId, budgetId);
  }
}
