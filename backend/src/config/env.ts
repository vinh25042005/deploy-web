// Centralized environment variable validation
// App sẽ crash ngay khi khởi động nếu thiếu biến bắt buộc,
// thay vì âm thầm dùng fallback không an toàn.

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`❌ FATAL: ${name} environment variable is not set`);
  }
  return value;
}

const JWT_SECRET = requireEnv('JWT_SECRET');
const DATABASE_URL = requireEnv('DATABASE_URL');

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
