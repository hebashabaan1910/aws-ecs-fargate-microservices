const http = require('http');
const url = require('url');
const { verifyTokenWithAuthService, triggerOrderNotification, AUTH_SERVICE_URL, NOTIFICATIONS_SERVICE_URL } = require('./clients');

const PORT = parseInt(process.env.PORT || '3001', 10);
const SERVICE_NAME = process.env.SERVICE_NAME || 'orders-service';

// In-memory Orders database
const ordersDb = [
  {
    id: 'ord_1001',
    userId: 'usr_admin_001',
    customerName: 'Administrator',
    customerEmail: 'admin@example.com',
    items: [{ name: 'AWS Solutions Architect Handbook', quantity: 1, price: 49.99 }],
    totalAmount: 49.99,
    status: 'COMPLETED',
    createdAt: new Date(Date.now() - 3600000).toISOString()
  }
];

function sendJson(res, statusCode, data, headers = {}) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Amzn-Trace-Id',
    ...headers
  });
  res.end(JSON.stringify(data, null, 2));
}

function parseRequestBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        resolve({});
      }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname.replace(/\/+$/, '') || '/';
  const method = req.method.toUpperCase();

  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Amzn-Trace-Id'
    });
    return res.end();
  }

  const traceId = req.headers['x-amzn-trace-id'] || 'none';
  console.log(`[${new Date().toISOString()}] ${method} ${pathname} (Trace: ${traceId})`);

  // Health Check for ALB Target Group
  if (pathname === '/health' || pathname === '/api/orders/health') {
    return sendJson(res, 200, {
      status: 'healthy',
      service: SERVICE_NAME,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      discovery: {
        authUrl: AUTH_SERVICE_URL,
        notificationsUrl: NOTIFICATIONS_SERVICE_URL
      }
    });
  }

  // Root Info
  if (pathname === '/' || pathname === '/api/orders') {
    if (method === 'GET' && !req.headers['authorization']) {
      return sendJson(res, 200, {
        message: `${SERVICE_NAME} running on ECS Fargate`,
        version: '1.0.0',
        routes: [
          'GET  /health',
          'GET  /api/orders (requires Bearer token)',
          'POST /api/orders (requires Bearer token)',
          'GET  /api/orders/:id (requires Bearer token)',
          'DELETE /api/orders/:id (requires Bearer token)'
        ]
      });
    }
  }

  // Helper authentication check against Auth microservice
  async function authenticate() {
    const authHeader = req.headers['authorization'];
    if (!authHeader) {
      return { authenticated: false, error: 'Authorization header is required (Bearer token)', status: 401 };
    }
    try {
      const authResult = await verifyTokenWithAuthService(authHeader, traceId);
      if (!authResult.valid) {
        return { authenticated: false, error: authResult.error || 'Unauthorized', status: 401 };
      }
      return { authenticated: true, user: authResult.user };
    } catch (e) {
      return {
        authenticated: false,
        error: 'Authentication verification unavailable (Service Discovery failure)',
        status: 503,
        details: e.message
      };
    }
  }

  // GET /api/orders
  if ((pathname === '/api/orders' || pathname === '/orders') && method === 'GET') {
    const auth = await authenticate();
    if (!auth.authenticated) {
      return sendJson(res, auth.status, { error: auth.error, details: auth.details });
    }

    const user = auth.user;
    let list = ordersDb;
    if (user.role !== 'admin') {
      list = ordersDb.filter((o) => o.userId === user.userId);
    }
    return sendJson(res, 200, { count: list.length, orders: list });
  }

  // POST /api/orders - Place a new order
  if ((pathname === '/api/orders' || pathname === '/orders') && method === 'POST') {
    const auth = await authenticate();
    if (!auth.authenticated) {
      return sendJson(res, auth.status, { error: auth.error, details: auth.details });
    }

    const body = await parseRequestBody(req);
    const { items } = body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return sendJson(res, 400, { error: 'Items array with at least one item is required' });
    }

    const totalAmount = items.reduce((sum, item) => sum + (item.price || 0) * (item.quantity || 1), 0);
    const newOrder = {
      id: `ord_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      userId: auth.user.userId,
      customerName: auth.user.name,
      customerEmail: auth.user.email,
      items,
      totalAmount: parseFloat(totalAmount.toFixed(2)),
      status: 'CONFIRMED',
      createdAt: new Date().toISOString()
    };

    ordersDb.unshift(newOrder);

    // Asynchronously dispatch notification through Cloud Map discovery
    const notifResult = await triggerOrderNotification({
      type: 'ORDER_PLACED',
      recipientEmail: auth.user.email,
      orderId: newOrder.id,
      amount: newOrder.totalAmount,
      message: `Your order #${newOrder.id} of $${newOrder.totalAmount} has been confirmed.`
    }, traceId);

    return sendJson(res, 201, {
      message: 'Order created successfully',
      order: newOrder,
      notificationDispatched: notifResult.status === 'success' || notifResult.status === 'sent'
    });
  }

  // Match /api/orders/:id or /orders/:id
  const orderIdMatch = pathname.match(/^\/(?:api\/orders|orders)\/([a-zA-Z0-9_-]+)$/);
  if (orderIdMatch) {
    const orderId = orderIdMatch[1];
    const auth = await authenticate();
    if (!auth.authenticated) {
      return sendJson(res, auth.status, { error: auth.error, details: auth.details });
    }

    const order = ordersDb.find((o) => o.id === orderId);
    if (!order) {
      return sendJson(res, 404, { error: 'Order not found' });
    }

    if (auth.user.role !== 'admin' && order.userId !== auth.user.userId) {
      return sendJson(res, 403, { error: 'Forbidden' });
    }

    if (method === 'GET') {
      return sendJson(res, 200, order);
    }

    if (method === 'DELETE') {
      order.status = 'CANCELLED';
      await triggerOrderNotification({
        type: 'ORDER_CANCELLED',
        recipientEmail: auth.user.email,
        orderId: order.id,
        message: `Your order #${order.id} has been cancelled.`
      }, traceId);
      return sendJson(res, 200, { message: 'Order cancelled successfully', order });
    }
  }

  return sendJson(res, 404, { error: 'Not Found', path: pathname });
});

server.listen(PORT, () => {
  console.log(`[${SERVICE_NAME}] Listening on port ${PORT}`);
});

process.on('SIGTERM', () => {
  console.log(`[${SERVICE_NAME}] Received SIGTERM, shutting down...`);
  server.close(() => process.exit(0));
});

module.exports = server;
