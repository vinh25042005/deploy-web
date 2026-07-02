// Admin - Product Management Page
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import api from '@/lib/api';
import { formatPrice, isAdmin } from '@/lib/auth';
import toast from 'react-hot-toast';
import Link from 'next/link';

export default function AdminProductsPage() {
  const router = useRouter();
  const [products, setProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState({ name: '', description: '', price: '', stock: '', imageUrl: '' });

  useEffect(() => {
    if (!isAdmin()) {
      router.push('/login');
      return;
    }
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    try {
      const res = await api.getProducts();
      setProducts(res.data || []);
    } catch (error: any) {
      toast.error(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const data = {
        name: form.name,
        description: form.description,
        price: Number(form.price),
        stock: Number(form.stock),
        imageUrl: form.imageUrl || undefined,
      };

      if (editId) {
        await api.updateProduct(editId, data);
        toast.success('Đã cập nhật sản phẩm!');
      } else {
        await api.createProduct(data);
        toast.success('Đã thêm sản phẩm!');
      }

      setShowForm(false);
      setEditId(null);
      setForm({ name: '', description: '', price: '', stock: '', imageUrl: '' });
      fetchProducts();
    } catch (error: any) {
      toast.error(error.message);
    }
  };

  const handleEdit = (product: any) => {
    setEditId(product.id);
    setForm({
      name: product.name,
      description: product.description,
      price: String(product.price),
      stock: String(product.stock),
      imageUrl: product.imageUrl || '',
    });
    setShowForm(true);
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Xóa sản phẩm này?')) return;
    try {
      await api.deleteProduct(id);
      toast.success('Đã xóa sản phẩm');
      fetchProducts();
    } catch (error: any) {
      toast.error(error.message);
    }
  };

  return (
    <div className="max-w-6xl mx-auto px-4 py-12">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-800">⚙️ Quản lý sản phẩm</h1>
        <div className="flex gap-4">
          <Link href="/admin/orders" className="text-primary-600 hover:underline">
            📦 Quản lý đơn hàng →
          </Link>
          <button
            onClick={() => { setShowForm(!showForm); setEditId(null); setForm({ name: '', description: '', price: '', stock: '', imageUrl: '' }); }}
            className="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition"
          >
            + Thêm sản phẩm
          </button>
        </div>
      </div>

      {showForm && (
        <div className="bg-white rounded-xl shadow-md p-6 mb-8">
          <h2 className="text-xl font-semibold mb-4">
            {editId ? '✏️ Sửa sản phẩm' : '➕ Thêm sản phẩm mới'}
          </h2>
          <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Tên sản phẩm</label>
              <input type="text" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required className="w-full px-3 py-2 border rounded-lg" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Giá (VNĐ)</label>
              <input type="number" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} required className="w-full px-3 py-2 border rounded-lg" />
            </div>
            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700 mb-1">Mô tả</label>
              <textarea value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} required rows={3} className="w-full px-3 py-2 border rounded-lg" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Số lượng</label>
              <input type="number" value={form.stock} onChange={(e) => setForm({ ...form, stock: e.target.value })} required className="w-full px-3 py-2 border rounded-lg" />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">URL Ảnh</label>
              <input type="url" value={form.imageUrl} onChange={(e) => setForm({ ...form, imageUrl: e.target.value })} className="w-full px-3 py-2 border rounded-lg" placeholder="https://..." />
            </div>
            <div className="md:col-span-2 flex gap-4">
              <button type="submit" className="bg-primary-600 text-white px-6 py-2 rounded-lg hover:bg-primary-700 transition">
                {editId ? 'Cập nhật' : 'Thêm mới'}
              </button>
              <button type="button" onClick={() => setShowForm(false)} className="text-gray-600 hover:text-gray-800">
                Hủy
              </button>
            </div>
          </form>
        </div>
      )}

      {loading ? (
        <div className="animate-pulse space-y-4">{[1,2,3].map(i => <div key={i} className="h-20 bg-gray-200 rounded-xl" />)}</div>
      ) : (
        <div className="bg-white rounded-xl shadow-md overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Sản phẩm</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Giá</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Tồn kho</th>
                <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Thao tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {products.map((p: any) => (
                <tr key={p.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <p className="font-medium text-gray-800">{p.name}</p>
                    <p className="text-sm text-gray-500 truncate max-w-xs">{p.description}</p>
                  </td>
                  <td className="px-6 py-4 text-red-600 font-medium">{formatPrice(Number(p.price))}</td>
                  <td className="px-6 py-4">{p.stock}</td>
                  <td className="px-6 py-4 text-right space-x-2">
                    <button onClick={() => handleEdit(p)} className="text-primary-600 hover:text-primary-800">✏️</button>
                    <button onClick={() => handleDelete(p.id)} className="text-red-600 hover:text-red-800">🗑️</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
