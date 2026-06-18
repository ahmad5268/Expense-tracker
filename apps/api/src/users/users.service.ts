import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { v2 as cloudinary } from 'cloudinary';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, name: true, avatarUrl: true, createdAt: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async updateMe(userId: string, dto: UpdateUserDto) {
    return this.prisma.user.update({
      where: { id: userId },
      data: dto,
      select: { id: true, email: true, name: true, avatarUrl: true, updatedAt: true },
    });
  }

  async uploadAvatar(userId: string, file: Express.Multer.File) {
    const result = await new Promise<{ secure_url: string }>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder: 'avatars', public_id: `user_${userId}`, overwrite: true, format: 'webp' },
        (error, result) => {
          if (error || !result) return reject(error);
          resolve(result as { secure_url: string });
        },
      );
      stream.end(file.buffer);
    });

    return this.prisma.user.update({
      where: { id: userId },
      data: { avatarUrl: result.secure_url },
      select: { id: true, avatarUrl: true },
    });
  }

  async updateFcmToken(userId: string, fcmToken: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken },
    });
  }
}
