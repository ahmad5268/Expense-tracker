import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, VerifyCallback, Profile } from 'passport-google-oauth20';
import { AuthService } from '../auth.service';

@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(private readonly authService: AuthService) {
    super({
      clientID: process.env.GOOGLE_CLIENT_ID || 'not-configured',
      clientSecret: process.env.GOOGLE_CLIENT_SECRET || 'not-configured',
      callbackURL: process.env.GOOGLE_CALLBACK_URL ?? 'http://localhost:3000/auth/google/callback',
      scope: ['email', 'profile'],
      // TODO(security): enable `state: true` once express-session is configured.
      // Without a session store passport-oauth2 cannot verify the state param,
      // leaving this flow open to CSRF. Add express-session + connect-redis before
      // enabling Google/Apple OAuth in production.
    });
  }

  async validate(_accessToken: string, _refreshToken: string, profile: Profile, done: VerifyCallback) {
    const email = profile.emails?.[0]?.value;
    const name = profile.displayName ?? profile.name?.givenName ?? 'User';

    if (!email) return done(new Error('No email from Google'), undefined);

    const tokens = await this.authService.upsertOAuthUser({
      email,
      name,
      oauthProvider: 'google',
      oauthId: profile.id,
    });

    done(null, tokens);
  }
}
