import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { RecurringService } from './recurring.service';
import { CreateRecurringRuleDto } from './dto/create-recurring.dto';
import { UpdateRecurringRuleDto } from './dto/update-recurring.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../workspaces/guards/workspace-member.guard';

@Controller('workspaces/:workspaceId/recurring')
@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
export class RecurringController {
  constructor(private readonly recurringService: RecurringService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.recurringService.findAll(workspaceId);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateRecurringRuleDto) {
    return this.recurringService.create(workspaceId, dto);
  }

  @Put(':ruleId')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('ruleId') ruleId: string,
    @Body() dto: UpdateRecurringRuleDto,
  ) {
    return this.recurringService.update(workspaceId, ruleId, dto);
  }

  @Delete(':ruleId')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@Param('workspaceId') workspaceId: string, @Param('ruleId') ruleId: string) {
    return this.recurringService.remove(workspaceId, ruleId);
  }
}
