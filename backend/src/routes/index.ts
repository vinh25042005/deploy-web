// API Routes
import { Router } from 'express';
import { authController } from '../controllers/auth.controller';
import { productController } from '../controllers/product.controller';
import { cartController } from '../controllers/cart.controller';
import { orderController } from '../controllers/order.controller';
import { authenticate, authorize } from '../middleware/auth';

const router = Router();

// ── Health Check ──────────────────────────────────────
router.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── Auth Routes ───────────────────────────────────────
router.post('/auth/register', (req, res, next) => authController.register(req, res, next));
router.post('/auth/login', (req, res, next) => authController.login(req, res, next));
router.get('/auth/profile', authenticate, (req, res, next) => authController.getProfile(req, res, next));

// ── Product Routes (Public Read, Admin Write) ──────────
router.get('/products', (req, res, next) => productController.getAll(req, res, next));
router.get('/products/:id', (req, res, next) => productController.getById(req, res, next));
router.post('/products', authenticate, authorize('ADMIN'), (req, res, next) => productController.create(req, res, next));
router.put('/products/:id', authenticate, authorize('ADMIN'), (req, res, next) => productController.update(req, res, next));
router.delete('/products/:id', authenticate, authorize('ADMIN'), (req, res, next) => productController.delete(req, res, next));

// ── Cart Routes (Authenticated) ────────────────────────
router.get('/cart', authenticate, (req, res, next) => cartController.getCart(req, res, next));
router.post('/cart/items', authenticate, (req, res, next) => cartController.addItem(req, res, next));
router.put('/cart/items/:productId', authenticate, (req, res, next) => cartController.updateItem(req, res, next));
router.delete('/cart/items/:productId', authenticate, (req, res, next) => cartController.removeItem(req, res, next));
router.delete('/cart', authenticate, (req, res, next) => cartController.clearCart(req, res, next));

// ── Order Routes ───────────────────────────────────────
router.post('/orders', authenticate, (req, res, next) => orderController.create(req, res, next));
router.get('/orders', authenticate, (req, res, next) => orderController.getUserOrders(req, res, next));
router.get('/orders/:id', authenticate, (req, res, next) => orderController.getById(req, res, next));
router.post('/orders/:id/cancel', authenticate, (req, res, next) => orderController.cancel(req, res, next));

// ── Admin Order Routes ─────────────────────────────────
router.get('/admin/orders', authenticate, authorize('ADMIN'), (req, res, next) => orderController.getAllOrders(req, res, next));
router.patch('/admin/orders/:id/status', authenticate, authorize('ADMIN'), (req, res, next) => orderController.updateStatus(req, res, next));

export default router;
