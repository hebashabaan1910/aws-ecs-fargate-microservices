const http = require('http');
const url = require('url');

const PORT = parseInt(process.env.PORT || '3002', 10);
const SERVICE_NAME = process.env.SERVICE_NAME || 'notifications-service';

const notificationsLog = [];

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
  if (pathname === '/health' || pathname === '/api/notifications/health') {
    return sendJson(res, 200, {
      status: 'healthy',
      service: SERVICE_NAME,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      sentCount: notificationsLog.length
    });
  }

  // Root Info
  if (pathname === '/' || pathname === '/api/notifications') {
    return sendJson(res, 200, {
      message: `${SERVICE_NAME} running on ECS Fargate`,
      version: '1.0.0',
      routes: [
        'GET  /health',
        'POST /api/notifications/send',
        'GET  /api/notifications/history'
      ]
    });
  }

  // POST /api/notifications/send
  if ((pathname === '/api/notifications/send' || pathname === '/send') && method === 'POST') {
    const body = await parseRequestBody(req);
    const { type, recipientEmail, orderId, message, metadata } = body;

    if (!recipientEmail || !message) {
      return sendJson(res, 400, { error: 'recipientEmail and message are required' });
    }

    const notification = {
      id: `notif_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      type: type || 'GENERAL_NOTIFICATION',
      recipientEmail,
      orderId: orderId || null,
      message,
      metadata: metadata || {},
      status: 'DELIVERED',
      sentAt: new Date().toISOString(),
      traceId
    };

    notificationsLog.unshift(notification);
    if (notificationsLog.length > 200) {
      notificationsLog.pop();
    }

    console.log(`[Notification Dispatched] ${notification.type} -> ${recipientEmail} (ID: ${notification.id})`);

    return sendJson(res, 200, {
      status: 'success',
      message: 'Notification dispatched successfully',
      notification
    });
  }

  // GET /api/notifications/history
  if ((pathname === '/api/notifications/history' || pathname === '/history') && method === 'GET') {
    const limit = parseInt(parsedUrl.query.limit || '20', 10);
    return sendJson(res, 200, {
      totalDispatched: notificationsLog.length,
      notifications: notificationsLog.slice(0, limit)
    });
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
