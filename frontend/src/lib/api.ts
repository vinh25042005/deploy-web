// API Client - Centralized HTTP requests
const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001/api';

interface ApiResponse<T = any> {
  status: string;
  data: T;
  message?: string;
  errors?: { field: string; message: string }[];
}

class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  private getToken(): string | null {
    if (typeof window === 'undefined') return null;
    return localStorage.getItem('token');
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const token = this.getToken();
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    if (token) {
      (headers as Record<string, string>)['Authorization'] = `Bearer ${token}`;
    }

    const response = await fetch(`${this.baseUrl}${endpoint}`, {
      ...options,
      headers,
      credentials: 'include',
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || `HTTP ${response.status}`);
    }

    return data;
  }

  // Auth
  register(name: string, email: string, password: string) {
    return this.request<{ user: any; token: string }>('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ name, email, password }),
    });
  }

  login(email: string, password: string) {
    return this.request<{ user: any; token: string }>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
  }

  getProfile() {
    return this.request<any>('/auth/profile');
  }

  // Products
  getProducts(params?: { categoryId?: string; search?: string }) {
    const query = new URLSearchParams();
    if (params?.categoryId) query.set('categoryId', params.categoryId);
    if (params?.search) query.set('search', params.search);
    const qs = query.toString();
    return this.request<any[]>(`/products${qs ? `?${qs}` : ''}`);
  }

  getProduct(id: string) {
    return this.request<any>(`/products/${id}`);
  }

  createProduct(data: any) {
    return this.request<any>('/products', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  updateProduct(id: string, data: any) {
    return this.request<any>(`/products/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  deleteProduct(id: string) {
    return this.request<any>(`/products/${id}`, { method: 'DELETE' });
  }

  // Cart
  getCart() {
    return this.request<any>('/cart');
  }

  addToCart(productId: string, quantity: number) {
    return this.request<any>('/cart/items', {
      method: 'POST',
      body: JSON.stringify({ productId, quantity }),
    });
  }

  updateCartItem(productId: string, quantity: number) {
    return this.request<any>(`/cart/items/${productId}`, {
      method: 'PUT',
      body: JSON.stringify({ quantity }),
    });
  }

  removeCartItem(productId: string) {
    return this.request<any>(`/cart/items/${productId}`, { method: 'DELETE' });
  }

  clearCart() {
    return this.request<any>('/cart', { method: 'DELETE' });
  }

  // Orders
  createOrder(items: { productId: string; quantity: number }[]) {
    return this.request<any>('/orders', {
      method: 'POST',
      body: JSON.stringify({ items }),
    });
  }

  getOrders() {
    return this.request<any[]>('/orders');
  }

  getOrder(id: string) {
    return this.request<any>(`/orders/${id}`);
  }

  cancelOrder(id: string) {
    return this.request<any>(`/orders/${id}/cancel`, { method: 'POST' });
  }

  // Admin
  getAllOrders() {
    return this.request<any[]>('/admin/orders');
  }

  updateOrderStatus(orderId: string, status: string) {
    return this.request<any>(`/admin/orders/${orderId}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    });
  }
}

export const api = new ApiClient(API_URL);
export default api;
