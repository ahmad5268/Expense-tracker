import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayInit,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Redis } from 'ioredis';

const NOTIFICATION_CHANNEL = 'notifications:new';

@WebSocketGateway({ namespace: '/notifications', cors: { origin: '*' } })
export class NotificationsGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer() server: Server;
  private readonly logger = new Logger(NotificationsGateway.name);
  private subscriber: Redis;

  constructor(private readonly jwtService: JwtService) {}

  afterInit() {
    this.subscriber = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
    this.subscriber.subscribe(NOTIFICATION_CHANNEL);
    this.subscriber.on('message', (_channel, message) => {
      try {
        const { userId, notification } = JSON.parse(message) as {
          userId: string;
          notification: object;
        };
        this.server.to(`user:${userId}`).emit('notification', notification);
      } catch {
        this.logger.error('Failed to parse notification message');
      }
    });
    this.logger.log('NotificationsGateway initialized');
  }

  async handleConnection(client: Socket) {
    try {
      const token =
        (client.handshake.auth as { token?: string })?.token ??
        client.handshake.headers?.authorization?.replace('Bearer ', '');
      if (!token) throw new Error('No token');
      const payload = this.jwtService.verify<{ sub: string }>(token);
      client.join(`user:${payload.sub}`);
      client.data.userId = payload.sub;
      this.logger.debug(`Client connected: user ${payload.sub}`);
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.debug(`Client disconnected: user ${(client.data as { userId?: string })?.userId}`);
  }

  static publish(publisher: Redis, userId: string, notification: object) {
    return publisher.publish(
      NOTIFICATION_CHANNEL,
      JSON.stringify({ userId, notification }),
    );
  }
}
