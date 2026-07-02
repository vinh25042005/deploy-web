// Auth utilities for client-side
'use client';

export interface User {
  id: string;
  email: string;
  name: string;
  role: 'ADMIN' | 'CUSTOMER';
}

export function getToken(): string | null {
  if (typeof window === 'undefined') return null;
  return localStorage.getItem('token');
}

export function setToken(token: string): void {
  localStorage.setItem('token', token);
}

export function removeToken(): void {
  localStorage.removeItem('token');
  localStorage.removeItem('user');
}

export function getUser(): User | null {
  if (typeof window === 'undefined') return null;
  const userStr = localStorage.getItem('user');
  if (!userStr) return null;
  try {
    return JSON.parse(userStr);
  } catch {
    return null;
  }
}

export function setUser(user: User): void {
  localStorage.setItem('user', JSON.stringify(user));
}

export function isLoggedIn(): boolean {
  return !!getToken();
}

export function isAdmin(): boolean {
  const user = getUser();
  return user?.role === 'ADMIN';
}

export function logout(): void {
  removeToken();
  window.location.href = '/';
}

export const formatPrice = (price: number): string => {
  return new Intl.NumberFormat('vi-VN', {
    style: 'currency',
    currency: 'VND',
  }).format(price);
};

export const orderStatusLabels: Record<string, { label: string; color: string }> = {
  PENDING: { label: 'Chờ xác nhận', color: 'bg-yellow-100 text-yellow-800' },
  CONFIRMED: { label: 'Đã xác nhận', color: 'bg-blue-100 text-blue-800' },
  SHIPPING: { label: 'Đang giao', color: 'bg-purple-100 text-purple-800' },
  DELIVERED: { label: 'Đã giao', color: 'bg-green-100 text-green-800' },
  CANCELLED: { label: 'Đã hủy', color: 'bg-red-100 text-red-800' },
};
