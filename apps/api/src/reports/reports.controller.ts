import { Controller, Get, Param, Query, UseGuards, Res } from '@nestjs/common';
import { Response } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../workspaces/guards/workspace-member.guard';
import { ReportsService } from './reports.service';
import { ReportQueryDto } from './dto/report-query.dto';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/reports')
export class ReportsController {
  constructor(private readonly service: ReportsService) {}

  private parseYearMonth(query: ReportQueryDto) {
    const now = new Date();
    return {
      year: query.year ?? now.getFullYear(),
      month: query.month ?? now.getMonth() + 1,
    };
  }

  @Get('summary')
  getSummary(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const { year, month } = this.parseYearMonth(query);
    return this.service.getSummary(wid, year, month);
  }

  @Get('by-category')
  getByCategory(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const { year, month } = this.parseYearMonth(query);
    return this.service.getByCategory(wid, year, month);
  }

  @Get('trends')
  getTrends(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const year = query.year ?? new Date().getFullYear();
    return this.service.getTrends(wid, year);
  }

  @Get('budget-vs-actual')
  getBudgetVsActual(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const { year, month } = this.parseYearMonth(query);
    return this.service.getBudgetVsActual(wid, year, month);
  }

  @Get('year-over-year')
  getYearOverYear(@Param('workspaceId') wid: string) {
    return this.service.getYearOverYear(wid);
  }

  @Get('heatmap')
  getHeatmap(@Param('workspaceId') wid: string, @Query() query: ReportQueryDto) {
    const year = query.year ?? new Date().getFullYear();
    return this.service.getHeatmap(wid, year);
  }

  @Get('export/csv')
  async exportCsv(
    @Param('workspaceId') wid: string,
    @Query() query: ReportQueryDto,
    @Res() res: Response,
  ) {
    const { year, month } = this.parseYearMonth(query);
    const buffer = await this.service.exportCsv(wid, year, month);
    const monthStr = String(month).padStart(2, '0');
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="transactions-${year}-${monthStr}.csv"`);
    res.end(buffer);
  }

  @Get('export/pdf')
  async exportPdf(
    @Param('workspaceId') wid: string,
    @Query() query: ReportQueryDto,
    @Res() res: Response,
  ) {
    const { year, month } = this.parseYearMonth(query);
    const stream = await this.service.exportPdf(wid, year, month);
    const monthStr = String(month).padStart(2, '0');
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="report-${year}-${monthStr}.pdf"`);
    stream.pipe(res);
  }
}
