// Footer Component
export default function Footer() {
  return (
    <footer className="bg-gray-800 text-white mt-auto">
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          <div>
            <h3 className="text-lg font-bold mb-3">🛍️ TechShop</h3>
            <p className="text-gray-400 text-sm">
              Cửa hàng công nghệ hàng đầu Việt Nam. Cam kết sản phẩm chính hãng, giá tốt nhất.
            </p>
          </div>
          <div>
            <h3 className="text-lg font-bold mb-3">Liên kết</h3>
            <ul className="space-y-2 text-gray-400 text-sm">
              <li><a href="/" className="hover:text-white transition">Sản phẩm</a></li>
              <li><a href="/cart" className="hover:text-white transition">Giỏ hàng</a></li>
              <li><a href="/orders" className="hover:text-white transition">Đơn hàng</a></li>
            </ul>
          </div>
          <div>
            <h3 className="text-lg font-bold mb-3">Liên hệ</h3>
            <ul className="space-y-2 text-gray-400 text-sm">
              <li>📧 support@techshop.vn</li>
              <li>📞 1900 1234</li>
              <li>📍 Hà Nội, Việt Nam</li>
            </ul>
          </div>
        </div>
        <div className="border-t border-gray-700 mt-8 pt-6 text-center text-gray-500 text-sm">
          © 2024 TechShop. DevOps Demo Project. All rights reserved.
        </div>
      </div>
    </footer>
  );
}
