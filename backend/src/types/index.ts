// Type definitions
import { Role, OrderStatus } from '@prisma/client';

export interface RegisterInput {
  email: string;
  name: string;
  password: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface CreateProductInput {
  name: string;
  description: string;
  price: number;
  stock: number;
  imageUrl?: string;
  categoryId?: string;
}

export interface UpdateProductInput {
  name?: string;
  description?: string;
  price?: number;
  stock?: number;
  imageUrl?: string;
  categoryId?: string;
}

export interface AddToCartInput {
  productId: string;
  quantity: number;
}

export interface CreateOrderInput {
  items: { productId: string; quantity: number }[];
}

export { Role, OrderStatus };
