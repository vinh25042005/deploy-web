// Order Service
import prisma from '../config/database';
import { AppError } from '../middleware/errorHandler';
import { OrderStatus } from '@prisma/client';

export class OrderService {
  async createOrder(userId: string, items: { productId: string; quantity: number }[]) {
    // Validate and calculate total
    let total = 0;
    const orderItems: { productId: string; quantity: number; price: number }[] = [];

    for (const item of items) {
      const product = await prisma.product.findUnique({ where: { id: item.productId } });
      if (!product) throw new AppError(`Product ${item.productId} not found`, 404);
      if (product.stock < item.quantity) {
        throw new AppError(`Not enough stock for ${product.name}`, 400);
      }

      total += Number(product.price) * item.quantity;
      orderItems.push({
        productId: item.productId,
        quantity: item.quantity,
        price: Number(product.price),
      });
    }

    // Create order and decrease stock in transaction
    const order = await prisma.$transaction(async (tx) => {
      const order = await tx.order.create({
        data: {
          userId,
          total,
          status: OrderStatus.PENDING,
          items: {
            create: orderItems,
          },
        },
        include: {
          items: { include: { product: true } },
        },
      });

      // Decrease stock
      for (const item of orderItems) {
        await tx.product.update({
          where: { id: item.productId },
          data: { stock: { decrement: item.quantity } },
        });
      }

      // Clear cart
      const cart = await tx.cart.findUnique({ where: { userId } });
      if (cart) {
        await tx.cartItem.deleteMany({ where: { cartId: cart.id } });
      }

      return order;
    });

    return order;
  }

  async getUserOrders(userId: string) {
    return prisma.order.findMany({
      where: { userId },
      include: { items: { include: { product: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getAllOrders() {
    return prisma.order.findMany({
      include: {
        user: { select: { id: true, name: true, email: true } },
        items: { include: { product: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getOrderById(orderId: string) {
    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        user: { select: { id: true, name: true, email: true } },
        items: { include: { product: true } },
      },
    });
    if (!order) throw new AppError('Order not found', 404);
    return order;
  }

  async updateOrderStatus(orderId: string, status: OrderStatus) {
    const order = await prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new AppError('Order not found', 404);

    return prisma.order.update({
      where: { id: orderId },
      data: { status },
      include: { items: { include: { product: true } } },
    });
  }

  async cancelOrder(orderId: string, userId: string) {
    const order = await prisma.order.findUnique({ where: { id: orderId } });
    if (!order) throw new AppError('Order not found', 404);
    if (order.userId !== userId) throw new AppError('Not authorized', 403);
    if (order.status !== OrderStatus.PENDING) {
      throw new AppError('Only pending orders can be cancelled', 400);
    }

    // Cancel and restore stock
    const updated = await prisma.$transaction(async (tx) => {
      const updatedOrder = await tx.order.update({
        where: { id: orderId },
        data: { status: OrderStatus.CANCELLED },
        include: { items: true },
      });

      for (const item of updatedOrder.items) {
        await tx.product.update({
          where: { id: item.productId },
          data: { stock: { increment: item.quantity } },
        });
      }

      return updatedOrder;
    });

    return updated;
  }
}

export const orderService = new OrderService();
