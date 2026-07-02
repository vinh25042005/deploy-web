// Order Controller
import { Response, NextFunction } from 'express';
import { orderService } from '../services/order.service';
import { createOrderSchema } from '../validators';
import { AuthRequest } from '../middleware/auth';
import { OrderStatus } from '@prisma/client';

export class OrderController {
  async create(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { items } = createOrderSchema.parse(req.body);
      const order = await orderService.createOrder(req.userId!, items);
      res.status(201).json({ status: 'success', data: order });
    } catch (error) {
      next(error);
    }
  }

  async getUserOrders(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const orders = await orderService.getUserOrders(req.userId!);
      res.json({ status: 'success', data: orders });
    } catch (error) {
      next(error);
    }
  }

  async getAllOrders(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const orders = await orderService.getAllOrders();
      res.json({ status: 'success', data: orders });
    } catch (error) {
      next(error);
    }
  }

  async getById(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const order = await orderService.getOrderById(req.params.id);
      res.json({ status: 'success', data: order });
    } catch (error) {
      next(error);
    }
  }

  async updateStatus(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { status } = req.body;
      if (!Object.values(OrderStatus).includes(status)) {
        res.status(400).json({ message: 'Invalid order status' });
        return;
      }
      const order = await orderService.updateOrderStatus(req.params.id, status);
      res.json({ status: 'success', data: order });
    } catch (error) {
      next(error);
    }
  }

  async cancel(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const order = await orderService.cancelOrder(req.params.id, req.userId!);
      res.json({ status: 'success', data: order });
    } catch (error) {
      next(error);
    }
  }
}

export const orderController = new OrderController();
