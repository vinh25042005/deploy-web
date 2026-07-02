// Auth Service
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import prisma from '../config/database';
import { RegisterInput, LoginInput } from '../types';
import { AppError } from '../middleware/errorHandler';

export class AuthService {
  async register(data: RegisterInput) {
    const existing = await prisma.user.findUnique({ where: { email: data.email } });
    if (existing) {
      throw new AppError('Email already registered', 400);
    }

    const hashedPassword = await bcrypt.hash(data.password, 10);
    const user = await prisma.user.create({
      data: { ...data, password: hashedPassword },
      select: { id: true, email: true, name: true, role: true, createdAt: true },
    });

    const token = this.generateToken(user.id, user.role);
    return { user, token };
  }

  async login(data: LoginInput) {
    const user = await prisma.user.findUnique({ where: { email: data.email } });
    if (!user) {
      throw new AppError('Invalid email or password', 401);
    }

    const isValid = await bcrypt.compare(data.password, user.password);
    if (!isValid) {
      throw new AppError('Invalid email or password', 401);
    }

    const token = this.generateToken(user.id, user.role);
    return {
      user: { id: user.id, email: user.email, name: user.name, role: user.role },
      token,
    };
  }

  async getProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, name: true, role: true, createdAt: true },
    });
    if (!user) throw new AppError('User not found', 404);
    return user;
  }

  private generateToken(userId: string, role: string): string {
    return jwt.sign(
      { userId, role },
      process.env.JWT_SECRET || 'fallback-secret',
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );
  }
}

export const authService = new AuthService();
