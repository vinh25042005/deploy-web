// Navbar Component
'use client';

import Link from 'next/link';
import { useState, useEffect } from 'react';
import { isLoggedIn, isAdmin, getUser, logout, User } from '@/lib/auth';

export default function Navbar() {
  const [user, setUser] = useState<User | null>(null);
  const [loggedIn, setLoggedIn] = useState(false);
  const [admin, setAdmin] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    setLoggedIn(isLoggedIn());
    setAdmin(isAdmin());
    setUser(getUser());
  }, []);

  return (
    <nav className="bg-white shadow-md sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4">
        <div className="flex justify-between items-center h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center space-x-2">
            <span className="text-2xl">🛍️</span>
            <span className="text-xl font-bold text-primary-600">TechShop</span>
          </Link>

          {/* Desktop Menu */}
          <div className="hidden md:flex items-center space-x-6">
            <Link href="/" className="text-gray-700 hover:text-primary-600 transition">
              Sản phẩm
            </Link>
            {loggedIn && (
              <Link href="/cart" className="text-gray-700 hover:text-primary-600 transition">
                🛒 Giỏ hàng
              </Link>
            )}
            {loggedIn && (
              <Link href="/orders" className="text-gray-700 hover:text-primary-600 transition">
                📦 Đơn hàng
              </Link>
            )}
            {admin && (
              <Link href="/admin/products" className="text-gray-700 hover:text-primary-600 transition font-medium">
                ⚙️ Admin
              </Link>
            )}
          </div>

          {/* Auth Buttons */}
          <div className="hidden md:flex items-center space-x-4">
            {loggedIn ? (
              <div className="flex items-center space-x-4">
                <span className="text-sm text-gray-600">
                  👤 {user?.name}
                </span>
                <button
                  onClick={logout}
                  className="text-sm text-red-600 hover:text-red-800 transition"
                >
                  Đăng xuất
                </button>
              </div>
            ) : (
              <>
                <Link
                  href="/login"
                  className="text-gray-700 hover:text-primary-600 transition"
                >
                  Đăng nhập
                </Link>
                <Link
                  href="/register"
                  className="bg-primary-600 text-white px-4 py-2 rounded-lg hover:bg-primary-700 transition"
                >
                  Đăng ký
                </Link>
              </>
            )}
          </div>

          {/* Mobile menu button */}
          <button
            onClick={() => setMenuOpen(!menuOpen)}
            className="md:hidden text-gray-700 focus:outline-none"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              {menuOpen ? (
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              ) : (
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              )}
            </svg>
          </button>
        </div>

        {/* Mobile Menu */}
        {menuOpen && (
          <div className="md:hidden pb-4 space-y-3">
            <Link href="/" className="block text-gray-700 hover:text-primary-600">Sản phẩm</Link>
            {loggedIn && <Link href="/cart" className="block text-gray-700 hover:text-primary-600">🛒 Giỏ hàng</Link>}
            {loggedIn && <Link href="/orders" className="block text-gray-700 hover:text-primary-600">📦 Đơn hàng</Link>}
            {admin && <Link href="/admin/products" className="block text-gray-700 hover:text-primary-600">⚙️ Admin</Link>}
            <hr />
            {loggedIn ? (
              <button onClick={logout} className="text-red-600">Đăng xuất</button>
            ) : (
              <div className="space-y-2">
                <Link href="/login" className="block text-gray-700">Đăng nhập</Link>
                <Link href="/register" className="block text-primary-600 font-medium">Đăng ký</Link>
              </div>
            )}
          </div>
        )}
      </div>
    </nav>
  );
}
