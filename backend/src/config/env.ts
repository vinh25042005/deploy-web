// Centralized environment variable validation
// App sẽ crash ngay khi khởi động nếu thiếu biến bắt buộc,
// thay vì âm thầm dùng fallback không an toàn.

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error('❌ FATAL: JWT_SECRET environment variable is not set');
  process.exit(1);
}

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error('❌ FATAL: DATABASE_URL environment variable is not set');
  process.exit(1);
}

const PORT = parseInt(process.env.PORT || '3001', 10);
const NODE_ENV = process.env.NODE_ENV || 'development';
const FRONTEND_URL = process.env.FRONTEND_URL || 'http://localhost:3000';

export {
  JWT_SECRET,
  DATABASE_URL,
  PORT,
  NODE_ENV,
  FRONTEND_URL,
};
