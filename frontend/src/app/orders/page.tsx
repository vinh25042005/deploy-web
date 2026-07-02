// Orders Page
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import api from '@/lib/api';
import { formatPrice, orderStatusLabels } from '@/lib/auth';
import toast from 'react-hot-toast';
import Link from 'next/link';

export default function OrdersPage() {
  const router = useRouter();
  const [orders, setOrders] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchOrders = async () => {
      try {
        const res = await api.getOrders();
        setOrders(res.data || []);
      } catch {
        toast.error('Vui lòng đăng nhập để xem đơn hàng');
        router.push('/login');
      } finally {
        setLoading(false);
      }
    };
    fetchOrders();
  }, []);

  const handleCancel = async (orderId: string) => {
    if (!confirm('Bạn có chắc muốn hủy đơn hàng này?')) return;
    try {
      await api.cancelOrder(orderId);
      toast.success('Đã hủy đơn hàng');
      const res = await api.getOrders();
      setOrders(res.data || []);
    } catch (error: any) {
      toast.error(error.message);
    }
  };

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12">
        <div className="animate-pulse space-y-4">
          {[1, 2].map((i) => (
            <div key={i} className="h-32 bg-gray-200 rounded-xl" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-12">
      <h1 className="text-3xl font-bold text-gray-800 mb-8">📦 Đơn hàng của tôi</h1>

      {orders.length === 0 ? (
        <div className="text-center py-12">
          <p className="text-6xl mb-4">📦</p>
          <p className="text-gray-500 text-lg mb-4">Chưa có đơn hàng nào</p>
          <Link href="/" className="text-primary-600 hover:underline">
            ← Mua sắm ngay
          </Link>
        </div>
      ) : (
        <div className="space-y-6">
          {orders.map((order: any) => {
            const statusInfo = orderStatusLabels[order.status] || { label: order.status, color: 'bg-gray-100' };
            return (
              <div key={order.id} className="bg-white rounded-xl shadow-md p-6">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <p className="text-sm text-gray-500">
                      Đơn hàng #{order.id.slice(0, 8)}
                    </p>
                    <p className="text-sm text-gray-400">
                      {new Date(order.createdAt).toLocaleString('vi-VN')}
                    </p>
                  </div>
                  <span className={`px-3 py-1 rounded-full text-sm font-medium ${statusInfo.color}`}>
                    {statusInfo.label}
                  </span>
                </div>

                <div className="space-y-2 mb-4">
                  {order.items?.map((item: any) => (
                    <div key={item.id} className="flex justify-between text-sm">
                      <span>{item.product?.name} × {item.quantity}</span>
                      <span>{formatPrice(Number(item.price) * item.quantity)}</span>
                    </div>
                  ))}
                </div>

                <div className="flex justify-between items-center border-t pt-4">
                  <span className="text-lg font-bold text-red-600">
                    {formatPrice(Number(order.total))}
                  </span>
                  {order.status === 'PENDING' && (
                    <button
                      onClick={() => handleCancel(order.id)}
                      className="text-red-600 hover:text-red-800 text-sm font-medium"
                    >
                      Hủy đơn
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
