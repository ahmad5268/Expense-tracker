import {
  Controller, Post, Body, UseGuards, Get, Req, Res, HttpCode, HttpStatus,
  NotFoundException,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { randomUUID } from 'crypto';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';
import { GoogleAuthGuard } from './guards/google-auth.guard';
import { AppleAuthGuard } from './guards/apple-auth.guard';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { RefreshPayload } from './strategies/jwt-refresh.strategy';
import { TokenPair } from './auth.service';

// Single-use exchange codes for OAuth callback — avoids tokens in redirect URLs.
// Code expires in 60 s and is consumed on first read.
const _exchangeCodes = new Map<string, { tokens: TokenPair; expiresAt: number }>();

function issueExchangeCode(tokens: TokenPair): string {
  const code = randomUUID();
  _exchangeCodes.set(code, { tokens, expiresAt: Date.now() + 60_000 });
  return code;
}

function consumeExchangeCode(code: string): TokenPair | null {
  const entry = _exchangeCodes.get(code);
  if (!entry || Date.now() > entry.expiresAt) {
    _exchangeCodes.delete(code);
    return null;
  }
  _exchangeCodes.delete(code);
  return entry.tokens;
}

@Controller('auth')
@Throttle({ default: { limit: process.env.NODE_ENV === 'test' ? 9999 : 5, ttl: 60000 } })
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: JwtPayload) {
    return this.authService.getMe(user.sub);
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtRefreshGuard)
  refresh(@Req() req: Request) {
    return this.authService.refresh(req.user as RefreshPayload);
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(JwtAuthGuard)
  async logout(@CurrentUser() user: JwtPayload) {
    await this.authService.logout(user.sub);
  }

  @Get('google')
  @UseGuards(GoogleAuthGuard)
  googleAuth() {
    // Passport redirects to Google
  }

  @Get('google/callback')
  @UseGuards(GoogleAuthGuard)
  googleCallback(@Req() req: Request, @Res() res: Response) {
    const tokens = req.user as TokenPair;
    const code = issueExchangeCode(tokens);
    res.redirect(`${process.env.FRONTEND_URL}/auth/callback?code=${code}`);
  }

  @Get('apple/callback')
  @UseGuards(AppleAuthGuard)
  appleCallback(@Req() req: Request, @Res() res: Response) {
    const tokens = req.user as TokenPair;
    const code = issueExchangeCode(tokens);
    res.redirect(`${process.env.FRONTEND_URL}/auth/callback?code=${code}`);
  }

  @Post('exchange')
  @HttpCode(HttpStatus.OK)
  exchange(@Body('code') code: string) {
    const tokens = consumeExchangeCode(code);
    if (!tokens) throw new NotFoundException('Exchange code is invalid or expired');
    return tokens;
  }

  @Post('forgot-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    await this.authService.forgotPassword(dto.email);
  }

  @Post('reset-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  async resetPassword(@Body() dto: ResetPasswordDto) {
    await this.authService.resetPassword(dto.token, dto.password);
  }
}
