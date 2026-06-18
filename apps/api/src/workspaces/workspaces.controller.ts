import { Controller, Post, Get, Put, Delete, Body, Param, UseGuards, HttpCode, HttpStatus, ForbiddenException, Request } from '@nestjs/common';
import { WorkspacesService } from './workspaces.service';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';
import { UpdateWorkspaceDto } from './dto/update-workspace.dto';
import { InviteMemberDto } from './dto/invite-member.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from './guards/workspace-member.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { MemberRole } from '@prisma/client';

@Controller('workspaces')
@UseGuards(JwtAuthGuard)
export class WorkspacesController {
  constructor(private readonly workspacesService: WorkspacesService) {}

  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateWorkspaceDto) {
    return this.workspacesService.create(user.sub, dto);
  }

  @Get()
  findAll(@CurrentUser() user: JwtPayload) {
    return this.workspacesService.findAll(user.sub);
  }

  @Put(':workspaceId')
  @UseGuards(WorkspaceMemberGuard)
  update(@Param('workspaceId') workspaceId: string, @Body() dto: UpdateWorkspaceDto, @Request() req: any) {
    const member = req.workspaceMember;
    if (![MemberRole.OWNER, MemberRole.ADMIN].includes(member.role)) {
      throw new ForbiddenException('Only workspace owners and admins can update workspace settings');
    }
    return this.workspacesService.update(workspaceId, dto);
  }

  @Post(':workspaceId/invite')
  @UseGuards(WorkspaceMemberGuard)
  invite(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: InviteMemberDto,
    @Request() req: any,
  ) {
    const member = req.workspaceMember;
    if (![MemberRole.OWNER, MemberRole.ADMIN].includes(member.role)) {
      throw new ForbiddenException('Only workspace owners and admins can invite members');
    }
    return this.workspacesService.invite(workspaceId, user.sub, dto.email);
  }

  @Post('join')
  @HttpCode(HttpStatus.NO_CONTENT)
  join(@CurrentUser() user: JwtPayload, @Body('token') token: string) {
    return this.workspacesService.join(user.sub, token);
  }

  @Delete(':workspaceId/members/:userId')
  @UseGuards(WorkspaceMemberGuard)
  @HttpCode(HttpStatus.NO_CONTENT)
  removeMember(
    @Param('workspaceId') workspaceId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.workspacesService.removeMember(workspaceId, user.sub, targetUserId);
  }
}
