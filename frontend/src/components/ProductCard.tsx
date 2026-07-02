// Product Card Component
'use client';

import Link from 'next/link';
import { formatPrice } from '@/lib/auth';
import { useState } from 'react';
import api from '@/lib/api';
import toast from 'react-hot-toast';

interface Product {
  id: string;
  name: string;
  description: string;
  price: string | number;
  imageUrl: string | null;
  stock: number;
  category?: { id: string; name: string } | null;
}

export default function ProductCard({ product }: { product: Product }) {
  const [adding, setAdding] = useState(false);

  const handleAddToCart = async () => {
    setAdding(true);
    try {
      await api.addToCart(product.id, 1);
      toast.success('Đã thêm vào giỏ hàng!');
    } catch (error: any) {
      toast.error(error.message || 'Vui lòng đăng nhập');
    } finally {
      setAdding(false);
    }
  };

  return (
    <div className="bg-white rounded-xl shadow-md overflow-hidden hover:shadow-xl transition-shadow duration-300 flex flex-col">
      <Link href={`/products/${product.id}`}>
        <div className="aspect-square bg-gray-100 overflow-hidden">
          {product.imageUrl ? (
            <img
              src={product.imageUrl}
              alt={product.name}
              className="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-gray-400">
              <span className="text-4xl">📦</span>
            </div>
          )}
        </div>
      </Link>
      <div className="p-4 flex flex-col flex-1">
        {product.category && (
          <span className="text-xs text-primary-600 font-medium mb-1">
            {product.category.name}
          </span>
        )}
        <Link href={`/products/${product.id}`}>
          <h3 className="font-semibold text-gray-800 mb-1 line-clamp-2 hover:text-primary-600 transition">
            {product.name}
          </h3>
        </Link>
        <p className="text-sm text-gray-500 mb-3 line-clamp-2 flex-1">
          {product.description}
        </p>
        <div className="flex items-center justify-between mt-auto">
          <span className="text-lg font-bold text-red-600">
            {formatPrice(Number(product.price))}
          </span>
          <span className="text-xs text-gray-400">
            {product.stock > 0 ? `${product.stock} sẵn` : 'Hết hàng'}
          </span>
        </div>
        <button
          onClick={handleAddToCart}
          disabled={adding || product.stock === 0}
          className="mt-3 w-full bg-primary-600 text-white py-2 rounded-lg hover:bg-primary-700 disabled:bg-gray-300 disabled:cursor-not-allowed transition text-sm font-medium"
        >
          {adding ? 'Đang thêm...' : '🛒 Thêm vào giỏ'}
        </button>
      </div>
    </div>
  );
}
