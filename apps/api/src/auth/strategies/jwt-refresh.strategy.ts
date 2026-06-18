import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { Request } from 'express';

export interface RefreshPayload {
  sub: string;
  email: string;
  refreshToken: string;
}

@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: Buffer.from(process.env.JWT_PUBLIC_KEY ?? '', 'base64').toString('utf8'),
      algorithms: ['RS256'],
      passReqToCallback: true,
    });
  }

  validate(req: Request, payload: { sub: string; email: string }): RefreshPayload {
    const refreshToken = req.headers.authorization?.replace('Bearer ', '') ?? '';
    return { sub: payload.sub, email: payload.email, refreshToken };
  }
}
