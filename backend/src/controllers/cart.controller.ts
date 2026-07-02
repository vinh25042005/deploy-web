// Cart Controller
import { Response, NextFunction } from 'express';
import { cartService } from '../services/cart.service';
import { addToCartSchema } from '../validators';
import { AuthRequest } from '../middleware/auth';

export class CartController {
  async getCart(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const cart = await cartService.getCart(req.userId!);
      res.json({ status: 'success', data: cart });
    } catch (error) {
      next(error);
    }
  }

  async addItem(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { productId, quantity } = addToCartSchema.parse(req.body);
      const item = await cartService.addItem(req.userId!, productId, quantity);
      res.status(201).json({ status: 'success', data: item });
    } catch (error) {
      next(error);
    }
  }

  async updateItem(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const { quantity } = req.body;
      const item = await cartService.updateItemQuantity(
        req.userId!,
        req.params.productId,
        quantity
      );
      res.json({ status: 'success', data: item });
    } catch (error) {
      next(error);
    }
  }

  async removeItem(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const result = await cartService.removeItem(req.userId!, req.params.productId);
      res.json({ status: 'success', data: result });
    } catch (error) {
      next(error);
    }
  }

  async clearCart(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const result = await cartService.clearCart(req.userId!);
      res.json({ status: 'success', data: result });
    } catch (error) {
      next(error);
    }
  }
}

export const cartController = new CartController();
