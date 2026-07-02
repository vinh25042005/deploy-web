// Cart Page
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import api from '@/lib/api';
import { formatPrice } from '@/lib/auth';
import toast from 'react-hot-toast';
import Link from 'next/link';

export default function CartPage() {
  const router = useRouter();
  const [cart, setCart] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  const fetchCart = async () => {
    try {
      const res = await api.getCart();
      setCart(res.data);
    } catch (error: any) {
      toast.error('Vui lòng đăng nhập để xem giỏ hàng');
      router.push('/login');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCart();
  }, []);

  const handleUpdateQuantity = async (productId: string, quantity: number) => {
    try {
      await api.updateCartItem(productId, quantity);
      fetchCart();
    } catch (error: any) {
      toast.error(error.message);
    }
  };

  const handleRemove = async (productId: string) => {
    try {
      await api.removeCartItem(productId);
      toast.success('Đã xóa khỏi giỏ hàng');
      fetchCart();
    } catch (error: any) {
      toast.error(error.message);
    }
  };

  const handleCheckout = async () => {
    if (!cart?.items?.length) return;
    try {
      const items = cart.items.map((item: any) => ({
        productId: item.productId,
        quantity: item.quantity,
      }));
      await api.createOrder(items);
      toast.success('Đặt hàng thành công!');
      router.push('/orders');
    } catch (error: any) {
      toast.error(error.message);
    }
  };

  const total = cart?.items?.reduce(
    (sum: number, item: any) => sum + Number(item.product.price) * item.quantity,
    0
  ) || 0;

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12">
        <div className="animate-pulse space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-24 bg-gray-200 rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-12">
      <h1 className="text-3xl font-bold text-gray-800 mb-8">🛒 Giỏ hàng</h1>

      {!cart?.items?.length ? (
        <div className="text-center py-12">
          <p className="text-6xl mb-4">🛒</p>
          <p className="text-gray-500 text-lg mb-4">Giỏ hàng trống</p>
          <Link href="/" className="text-primary-600 hover:underline">
            ← Tiếp tục mua sắm
          </Link>
        </div>
      ) : (
        <>
          <div className="space-y-4 mb-8">
            {cart.items.map((item: any) => (
              <div
                key={item.id}
                className="bg-white rounded-xl shadow-md p-4 flex items-center gap-4"
              >
                <div className="w-20 h-20 bg-gray-100 rounded-lg overflow-hidden flex-shrink-0">
                  {item.product.imageUrl ? (
                    <img src={item.product.imageUrl} alt={item.product.name} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-2xl">📦</div>
                  )}
                </div>
                <div className="flex-1">
                  <h3 className="font-semibold text-gray-800">{item.product.name}</h3>
                  <p className="text-red-600 font-medium">
                    {formatPrice(Number(item.product.price))}
                  </p>
                </div>
                <div className="flex items-center border rounded-lg">
                  <button
                    onClick={() => handleUpdateQuantity(item.productId, item.quantity - 1)}
                    className="px-3 py-1 hover:bg-gray-100"
                  >
                    −
                  </button>
                  <span className="px-4 py-1 font-medium">{item.quantity}</span>
                  <button
                    onClick={() => handleUpdateQuantity(item.productId, item.quantity + 1)}
                    className="px-3 py-1 hover:bg-gray-100"
                  >
                    +
                  </button>
                </div>
                <p className="font-bold text-gray-800 w-28 text-right">
                  {formatPrice(Number(item.product.price) * item.quantity)}
                </p>
                <button
                  onClick={() => handleRemove(item.productId)}
                  className="text-red-500 hover:text-red-700 transition"
                >
                  🗑️
                </button>
              </div>
            ))}
          </div>

          <div className="bg-white rounded-xl shadow-md p-6">
            <div className="flex justify-between items-center mb-4">
              <span className="text-lg text-gray-600">Tổng cộng:</span>
              <span className="text-2xl font-bold text-red-600">{formatPrice(total)}</span>
            </div>
            <button
              onClick={handleCheckout}
              className="w-full bg-red-600 text-white py-3 rounded-lg hover:bg-red-700 transition font-medium text-lg"
            >
              🎉 Đặt hàng ngay
            </button>
          </div>
        </>
      )}
    </div>
  );
}
