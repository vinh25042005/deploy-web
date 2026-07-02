// Product Controller
import { Request, Response, NextFunction } from 'express';
import { productService } from '../services/product.service';
import { createProductSchema, updateProductSchema } from '../validators';
import { AuthRequest } from '../middleware/auth';

export class ProductController {
  async getAll(req: Request, res: Response, next: NextFunction) {
    try {
      const { categoryId, search } = req.query;
      const products = await productService.findAll(
        categoryId as string | undefined,
        search as string | undefined
      );
      res.json({ status: 'success', data: products });
    } catch (error) {
      next(error);
    }
  }

  async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const product = await productService.findById(req.params.id);
      res.json({ status: 'success', data: product });
    } catch (error) {
      next(error);
    }
  }

  async create(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const data = createProductSchema.parse(req.body);
      const product = await productService.create(data);
      res.status(201).json({ status: 'success', data: product });
    } catch (error) {
      next(error);
    }
  }

  async update(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const data = updateProductSchema.parse(req.body);
      const product = await productService.update(req.params.id, data);
      res.json({ status: 'success', data: product });
    } catch (error) {
      next(error);
    }
  }

  async delete(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      await productService.delete(req.params.id);
      res.json({ status: 'success', message: 'Product deleted' });
    } catch (error) {
      next(error);
    }
  }
}

export const productController = new ProductController();
