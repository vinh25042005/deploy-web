// Swagger API Documentation
import swaggerJsdoc from 'swagger-jsdoc';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'E-Commerce API',
      version: '1.0.0',
      description: 'REST API for Simple E-Commerce Application - DevOps Demo Project',
      contact: {
        name: 'Developer',
      },
    },
    servers: [
      {
        url: 'http://localhost:3001/api',
        description: 'Development server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
    tags: [
      { name: 'Auth', description: 'Authentication endpoints' },
      { name: 'Products', description: 'Product CRUD' },
      { name: 'Cart', description: 'Shopping cart management' },
      { name: 'Orders', description: 'Order management' },
    ],
  },
  apis: ['./src/routes/*.ts'], // Path to API routes with JSDoc comments
};

export const swaggerSpec = swaggerJsdoc(options);
