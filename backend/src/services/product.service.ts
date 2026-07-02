// Product Service
import prisma from '../config/database';
import { CreateProductInput, UpdateProductInput } from '../types';
import { AppError } from '../middleware/errorHandler';

export class ProductService {
  async findAll(categoryId?: string, search?: string) {
    const where: any = {};
    if (categoryId) where.categoryId = categoryId;
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
      ];
    }
    return prisma.product.findMany({
      where,
      include: { category: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findById(id: string) {
    const product = await prisma.product.findUnique({
      where: { id },
      include: { category: true },
    });
    if (!product) throw new AppError('Product not found', 404);
    return product;
  }

  async create(data: CreateProductInput) {
    return prisma.product.create({ data, include: { category: true } });
  }

  async update(id: string, data: UpdateProductInput) {
    await this.findById(id); // check exists
    return prisma.product.update({
      where: { id },
      data,
      include: { category: true },
    });
  }

  async delete(id: string) {
    await this.findById(id);
    return prisma.product.delete({ where: { id } });
  }
}

export const productService = new ProductService();
