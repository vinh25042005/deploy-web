// Admin - Order Management Page
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import api from '@/lib/api';
import { formatPrice, orderStatusLabels, isAdmin } from '@/lib/auth';
import toast from 'react-hot-toast';
import Link from 'next/link';

export default function AdminOrdersPage() {
  const router = useRouter();
  const [orders, setOrders] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isAdmin()) {
      router.push('/login');
      return;
    }
    fetchOrders();
  }, []);

  const fetchOrders = async () => {
    try {
      const res = await api.getAllOrders();
      setOrders(res.data || []);
    } catch (error: any) {
      toast.error(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (orderId: string, status: string) => {
    try {
      await api.updateOrderStatus(orderId, status);
      toast.success('Đã cập nhật trạng thái');
      fetchOrders();
    } catch (error: any) {
      toast.error(error.message);
    }
  };

  return (
    <div className="max-w-6xl mx-auto px-4 py-12">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-800">📦 Quản lý đơn hàng</h1>
        <Link href="/admin/products" className="text-primary-600 hover:underline">
          ← Quản lý sản phẩm
        </Link>
      </div>

      {loading ? (
        <div className="animate-pulse space-y-4">{[1,2,3].map(i => <div key={i} className="h-32 bg-gray-200 rounded-xl" />)}</div>
      ) : orders.length === 0 ? (
        <div className="text-center py-12 text-gray-500">Chưa có đơn hàng nào.</div>
      ) : (
        <div className="space-y-6">
          {orders.map((order: any) => {
            const statusInfo = orderStatusLabels[order.status] || { label: order.status, color: 'bg-gray-100' };
            const nextStatuses = {
              PENDING: 'CONFIRMED',
              CONFIRMED: 'SHIPPING',
              SHIPPING: 'DELIVERED',
            } as const;

            return (
              <div key={order.id} className="bg-white rounded-xl shadow-md p-6">
                <div className="flex flex-wrap justify-between items-start gap-4 mb-4">
                  <div>
                    <p className="font-medium text-gray-800">
                      #{order.id.slice(0, 8)} — {order.user?.name || 'N/A'}
                    </p>
                    <p className="text-sm text-gray-500">{order.user?.email}</p>
                    <p className="text-xs text-gray-400">
                      {new Date(order.createdAt).toLocaleString('vi-VN')}
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className={`px-3 py-1 rounded-full text-sm font-medium ${statusInfo.color}`}>
                      {statusInfo.label}
                    </span>
                    {order.status !== 'DELIVERED' && order.status !== 'CANCELLED' && (
                      <select
                        value={order.status}
                        onChange={(e) => handleStatusChange(order.id, e.target.value)}
                        className="text-sm border rounded-lg px-3 py-1"
                      >
                        {Object.entries(orderStatusLabels).map(([key, val]) => (
                          <option key={key} value={key}>{val.label}</option>
                        ))}
                      </select>
                    )}
                  </div>
                </div>

                <div className="space-y-2 mb-4">
                  {order.items?.map((item: any) => (
                    <div key={item.id} className="flex justify-between text-sm">
                      <span>{item.product?.name} × {item.quantity}</span>
                      <span>{formatPrice(Number(item.price) * item.quantity)}</span>
                    </div>
                  ))}
                </div>

                <div className="border-t pt-4 text-right">
                  <span className="text-lg font-bold text-red-600">
                    {formatPrice(Number(order.total))}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
