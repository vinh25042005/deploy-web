// Cart Service
import prisma from '../config/database';
import { AppError } from '../middleware/errorHandler';

export class CartService {
  async getCart(userId: string) {
    let cart = await prisma.cart.findUnique({
      where: { userId },
      include: {
        items: {
          include: { product: true },
        },
      },
    });

    if (!cart) {
      cart = await prisma.cart.create({
        data: { userId },
        include: { items: { include: { product: true } } },
      });
    }

    return cart;
  }

  async addItem(userId: string, productId: string, quantity: number) {
    // Check product exists & has stock
    const product = await prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new AppError('Product not found', 404);
    if (product.stock < quantity) throw new AppError('Not enough stock', 400);

    // Get or create cart
    let cart = await prisma.cart.findUnique({ where: { userId } });
    if (!cart) {
      cart = await prisma.cart.create({ data: { userId } });
    }

    // Upsert cart item
    const existingItem = await prisma.cartItem.findUnique({
      where: { cartId_productId: { cartId: cart.id, productId } },
    });

    if (existingItem) {
      return prisma.cartItem.update({
        where: { id: existingItem.id },
        data: { quantity: existingItem.quantity + quantity },
        include: { product: true },
      });
    }

    return prisma.cartItem.create({
      data: { cartId: cart.id, productId, quantity },
      include: { product: true },
    });
  }

  async updateItemQuantity(userId: string, productId: string, quantity: number) {
    const cart = await prisma.cart.findUnique({ where: { userId } });
    if (!cart) throw new AppError('Cart not found', 404);

    if (quantity <= 0) {
      await prisma.cartItem.deleteMany({
        where: { cartId: cart.id, productId },
      });
      return null;
    }

    return prisma.cartItem.update({
      where: { cartId_productId: { cartId: cart.id, productId } },
      data: { quantity },
      include: { product: true },
    });
  }

  async removeItem(userId: string, productId: string) {
    const cart = await prisma.cart.findUnique({ where: { userId } });
    if (!cart) throw new AppError('Cart not found', 404);

    await prisma.cartItem.deleteMany({
      where: { cartId: cart.id, productId },
    });

    return { message: 'Item removed from cart' };
  }

  async clearCart(userId: string) {
    const cart = await prisma.cart.findUnique({ where: { userId } });
    if (cart) {
      await prisma.cartItem.deleteMany({ where: { cartId: cart.id } });
    }
    return { message: 'Cart cleared' };
  }
}

export const cartService = new CartService();
