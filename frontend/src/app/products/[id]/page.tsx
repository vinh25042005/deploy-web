// Product Detail Page
'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import api from '@/lib/api';
import { formatPrice } from '@/lib/auth';
import toast from 'react-hot-toast';

export default function ProductDetailPage() {
  const { id } = useParams();
  const router = useRouter();
  const [product, setProduct] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [quantity, setQuantity] = useState(1);

  useEffect(() => {
    const fetchProduct = async () => {
      try {
        const res = await api.getProduct(id as string);
        setProduct(res.data);
      } catch {
        toast.error('Không tìm thấy sản phẩm');
      } finally {
        setLoading(false);
      }
    };
    fetchProduct();
  }, [id]);

  const handleAddToCart = async () => {
    try {
      await api.addToCart(product.id, quantity);
      toast.success('Đã thêm vào giỏ hàng!');
    } catch (error: any) {
      toast.error(error.message || 'Vui lòng đăng nhập');
    }
  };

  const handleBuyNow = async () => {
    try {
      await api.addToCart(product.id, quantity);
      router.push('/cart');
    } catch (error: any) {
      toast.error(error.message || 'Vui lòng đăng nhập');
    }
  };

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="animate-pulse grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="aspect-square bg-gray-200 rounded-xl" />
          <div className="space-y-4">
            <div className="h-8 bg-gray-200 rounded w-3/4" />
            <div className="h-4 bg-gray-200 rounded w-1/2" />
            <div className="h-6 bg-gray-200 rounded w-1/3" />
          </div>
        </div>
      </div>
    );
  }

  if (!product) return null;

  return (
    <div className="max-w-7xl mx-auto px-4 py-12">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {/* Product Image */}
        <div className="aspect-square bg-gray-100 rounded-xl overflow-hidden">
          {product.imageUrl ? (
            <img src={product.imageUrl} alt={product.name} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-6xl">📦</div>
          )}
        </div>

        {/* Product Info */}
        <div>
          {product.category && (
            <span className="text-sm text-primary-600 font-medium">
              {product.category.name}
            </span>
          )}
          <h1 className="text-3xl font-bold text-gray-800 mt-2 mb-4">{product.name}</h1>
          <p className="text-gray-600 mb-6 leading-relaxed">{product.description}</p>

          <div className="text-3xl font-bold text-red-600 mb-4">
            {formatPrice(Number(product.price))}
          </div>

          <div className="flex items-center gap-2 mb-6">
            <span className={`px-3 py-1 rounded-full text-sm ${
              product.stock > 0 ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
            }`}>
              {product.stock > 0 ? `Còn ${product.stock} sản phẩm` : 'Hết hàng'}
            </span>
          </div>

          {/* Quantity + Add to Cart */}
          <div className="flex items-center gap-4 mb-6">
            <div className="flex items-center border rounded-lg">
              <button
                onClick={() => setQuantity(Math.max(1, quantity - 1))}
                className="px-4 py-2 hover:bg-gray-100 transition"
              >
                −
              </button>
              <span className="px-6 py-2 font-medium">{quantity}</span>
              <button
                onClick={() => setQuantity(Math.min(product.stock, quantity + 1))}
                className="px-4 py-2 hover:bg-gray-100 transition"
              >
                +
              </button>
            </div>
          </div>

          <div className="flex gap-4">
            <button
              onClick={handleAddToCart}
              disabled={product.stock === 0}
              className="flex-1 bg-primary-600 text-white py-3 rounded-lg hover:bg-primary-700 disabled:bg-gray-300 transition font-medium"
            >
              🛒 Thêm vào giỏ hàng
            </button>
            <button
              onClick={handleBuyNow}
              disabled={product.stock === 0}
              className="flex-1 bg-red-600 text-white py-3 rounded-lg hover:bg-red-700 disabled:bg-gray-300 transition font-medium"
            >
              ⚡ Mua ngay
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
