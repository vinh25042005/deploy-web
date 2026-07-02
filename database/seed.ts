// Database Seed Script
// Run: npx prisma db seed

import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // Clean up
  await prisma.cartItem.deleteMany();
  await prisma.cart.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.product.deleteMany();
  await prisma.category.deleteMany();
  await prisma.user.deleteMany();

  // Create admin user (password: admin123)
  const adminHash = await bcrypt.hash('admin123', 10);
  const admin = await prisma.user.create({
    data: {
      email: 'admin@shop.com',
      name: 'Admin',
      password: adminHash,
      role: Role.ADMIN,
    },
  });
  console.log(`✅ Admin user: ${admin.email}`);

  // Create customer (password: customer123)
  const customerHash = await bcrypt.hash('customer123', 10);
  const customer = await prisma.user.create({
    data: {
      email: 'customer@shop.com',
      name: 'Khách Hàng',
      password: customerHash,
      role: Role.CUSTOMER,
    },
  });
  console.log(`✅ Customer user: ${customer.email}`);

  // Create categories
  const categories = await Promise.all([
    prisma.category.create({ data: { name: 'Điện thoại' } }),
    prisma.category.create({ data: { name: 'Laptop' } }),
    prisma.category.create({ data: { name: 'Phụ kiện' } }),
    prisma.category.create({ data: { name: 'Máy tính bảng' } }),
  ]);
  console.log('✅ Categories created');

  // Create products
  const products = await Promise.all([
    prisma.product.create({
      data: {
        name: 'iPhone 15 Pro Max',
        description: 'Điện thoại cao cấp nhất của Apple với chip A17 Pro',
        price: 32990000,
        stock: 50,
        imageUrl: 'https://picsum.photos/seed/iphone15/400',
        categoryId: categories[0].id,
      },
    }),
    prisma.product.create({
      data: {
        name: 'Samsung Galaxy S24 Ultra',
        description: 'Flagship Android với bút S-Pen và camera 200MP',
        price: 28990000,
        stock: 40,
        imageUrl: 'https://picsum.photos/seed/samsung24/400',
        categoryId: categories[0].id,
      },
    }),
    prisma.product.create({
      data: {
        name: 'MacBook Pro 14 M3',
        description: 'Laptop chuyên nghiệp với chip Apple M3 Pro',
        price: 49990000,
        stock: 25,
        imageUrl: 'https://picsum.photos/seed/macbook/400',
        categoryId: categories[1].id,
      },
    }),
    prisma.product.create({
      data: {
        name: 'Dell XPS 15',
        description: 'Laptop Windows cao cấp, màn hình OLED 3.5K',
        price: 35990000,
        stock: 20,
        imageUrl: 'https://picsum.photos/seed/dellxps/400',
        categoryId: categories[1].id,
      },
    }),
    prisma.product.create({
      data: {
        name: 'AirPods Pro 2',
        description: 'Tai nghe chống ồn chủ động, chip H2',
        price: 5290000,
        stock: 100,
        imageUrl: 'https://picsum.photos/seed/airpods/400',
        categoryId: categories[2].id,
      },
    }),
    prisma.product.create({
      data: {
        name: 'iPad Air M2',
        description: 'Máy tính bảng mạnh mẽ với chip M2',
        price: 16990000,
        stock: 30,
        imageUrl: 'https://picsum.photos/seed/ipad/400',
        categoryId: categories[3].id,
      },
    }),
    prisma.product.create({
      data: {
        name: 'Sạc nhanh GaN 65W',
        description: 'Củ sạc nhanh công nghệ GaN nhỏ gọn',
        price: 590000,
        stock: 200,
        imageUrl: 'https://picsum.photos/seed/charger/400',
        categoryId: categories[2].id,
      },
    }),
    prisma.product.create({
      data: {
        name: 'Cáp USB-C to Lightning',
        description: 'Cáp sạc chính hãng, dài 2m',
        price: 350000,
        stock: 300,
        imageUrl: 'https://picsum.photos/seed/cable/400',
        categoryId: categories[2].id,
      },
    }),
  ]);
  console.log(`✅ ${products.length} products created`);

  console.log('\n🎉 Seed completed!');
  console.log('📧 Admin: admin@shop.com / admin123');
  console.log('📧 Customer: customer@shop.com / customer123');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
