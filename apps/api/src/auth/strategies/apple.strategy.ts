import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import Strategy from 'passport-apple';
import { AuthService } from '../auth.service';

@Injectable()
export class AppleStrategy extends PassportStrategy(Strategy, 'apple') {
  constructor(private readonly authService: AuthService) {
    super({
      clientID: process.env.APPLE_CLIENT_ID ?? '',
      teamID: process.env.APPLE_TEAM_ID ?? '',
      keyID: process.env.APPLE_KEY_ID ?? '',
      privateKeyString: process.env.APPLE_PRIVATE_KEY ?? '',
      callbackURL: process.env.APPLE_CALLBACK_URL ?? 'http://localhost:3000/auth/apple/callback',
      scope: ['email', 'name'],
      // TODO(security): add CSRF state once express-session is configured (see google.strategy.ts)
    });
  }

  async validate(
    _accessToken: string,
    _refreshToken: string,
    idToken: { sub: string; email?: string },
    profile: { name?: { firstName?: string; lastName?: string } },
    done: (err: Error | null, user?: unknown) => void,
  ) {
    const email = idToken.email;
    if (!email) return done(new Error('No email from Apple'));

    const firstName = profile?.name?.firstName ?? '';
    const lastName = profile?.name?.lastName ?? '';
    const name = `${firstName} ${lastName}`.trim() || 'Apple User';

    const tokens = await this.authService.upsertOAuthUser({
      email,
      name,
      oauthProvider: 'apple',
      oauthId: idToken.sub,
    });

    done(null, tokens);
  }
}
