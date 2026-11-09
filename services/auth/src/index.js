const http = require('http');
const crypto = require('crypto');
const url = require('url');
const redisClient = require('./redisClient');

const PORT = parseInt(process.env.PORT || '3000', 10);
const SERVICE_NAME = process.env.SERVICE_NAME || 'auth-service';
const JWT_SECRET = process.env.JWT_SECRET || 'default-super-secret-jwt-key-change-in-prod';

// In-memory Users store
const usersDb = new Map();

// Helper: Hash password using PBKDF2
function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');
  return { salt, hash };
}

function verifyPassword(password, salt, originalHash) {
  const hash = crypto.pbkdf2Sync(password, salt, 1000, 64, 'sha512').toString('hex');
  return hash === originalHash;
}

// Helper: Sign JWT
function signJWT(payload, secret = JWT_SECRET, expiresInSec = 86400) {
  const header = { alg: 'HS256', typ: 'JWT' };
  const exp = Math.floor(Date.now() / 1000) + expiresInSec;
  const fullPayload = { ...payload, exp, iat: Math.floor(Date.now() / 1000) };

  const encode = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
  const part1 = encode(header);
  const part2 = encode(fullPayload);
  const signature = crypto.createHmac('sha256', secret).update(`${part1}.${part2}`).digest('base64url');

  return `${part1}.${part2}.${signature}`;
}

// Helper: Verify JWT
function verifyJWT(token, secret = JWT_SECRET) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const [part1, part2, signature] = parts;
    const expectedSig = crypto.createHmac('sha256', secret).update(`${part1}.${part2}`).digest('base64url');
    if (expectedSig !== signature) return null;

    const payload = JSON.parse(Buffer.from(part2, 'base64url').toString('utf8'));
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch (e) {
    return null;
  }
}

// Seed Demo Admin User
(() => {
  const { salt, hash } = hashPassword('admin123');
  usersDb.set('admin@example.com', {
    id: 'usr_admin_001',
    name: 'Administrator',
    email: 'admin@example.com',
    salt,
    hash,
    role: 'admin'
  });
})();

// Helper to send JSON responses
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

// Helper to read JSON request body
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

  // Handle CORS Preflight
  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Amzn-Trace-Id'
    });
    return res.end();
  }

  // AWS X-Ray Trace Context Logging
  const traceId = req.headers['x-amzn-trace-id'] || 'none';
  console.log(`[${new Date().toISOString()}] ${method} ${pathname} (Trace: ${traceId})`);

  // Health Check for ALB Target Group
  if (pathname === '/health' || pathname === '/api/auth/health') {
    return sendJson(res, 200, {
      status: 'healthy',
      service: SERVICE_NAME,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      redis: redisClient.isReady() ? 'connected' : 'in-memory-fallback'
    });
  }

  // Root Info
  if (pathname === '/' || pathname === '/api/auth') {
    return sendJson(res, 200, {
      message: `${SERVICE_NAME} running on ECS Fargate`,
      version: '1.0.0',
      routes: [
        'GET  /health',
        'POST /api/auth/register',
        'POST /api/auth/login',
        'GET  /api/auth/verify',
        'POST /api/auth/logout'
      ]
    });
  }

  // POST /api/auth/register
  if ((pathname === '/api/auth/register' || pathname === '/register') && method === 'POST') {
    const body = await parseRequestBody(req);
    const { name, email, password } = body;

    if (!name || !email || !password) {
      return sendJson(res, 400, { error: 'Name, email, and password are required' });
    }

    if (usersDb.has(email.toLowerCase())) {
      return sendJson(res, 409, { error: 'User with this email already exists' });
    }

    const { salt, hash } = hashPassword(password);
    const userId = `usr_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const user = {
      id: userId,
      name,
      email: email.toLowerCase(),
      salt,
      hash,
      role: 'customer',
      createdAt: new Date().toISOString()
    };

    usersDb.set(email.toLowerCase(), user);

    return sendJson(res, 201, {
      message: 'User registered successfully',
      user: { id: user.id, name: user.name, email: user.email, role: user.role }
    });
  }

  // POST /api/auth/login
  if ((pathname === '/api/auth/login' || pathname === '/login') && method === 'POST') {
    const body = await parseRequestBody(req);
    const { email, password } = body;

    if (!email || !password) {
      return sendJson(res, 400, { error: 'Email and password are required' });
    }

    const user = usersDb.get(email.toLowerCase());
    if (!user || !verifyPassword(password, user.salt, user.hash)) {
      return sendJson(res, 401, { error: 'Invalid email or password' });
    }

    const tokenPayload = {
      userId: user.id,
      name: user.name,
      email: user.email,
      role: user.role
    };

    const token = signJWT(tokenPayload, JWT_SECRET, 86400);

    // Save session in Redis
    await redisClient.set(`session:${user.id}`, JSON.stringify({
      userId: user.id,
      token,
      loginAt: new Date().toISOString()
    }), 'EX', 86400);

    return sendJson(res, 200, {
      message: 'Login successful',
      token,
      user: tokenPayload
    });
  }

  // GET /api/auth/verify (Used by Orders Service via Cloud Map discovery)
  if ((pathname === '/api/auth/verify' || pathname === '/verify') && method === 'GET') {
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return sendJson(res, 401, { valid: false, error: 'Missing or malformed Authorization header' });
    }

    const token = authHeader.substring(7);
    const decoded = verifyJWT(token, JWT_SECRET);

    if (!decoded) {
      return sendJson(res, 401, { valid: false, error: 'Token is invalid or expired' });
    }

    // Verify session in Redis
    const sessionData = await redisClient.get(`session:${decoded.userId}`);

    return sendJson(res, 200, {
      valid: true,
      user: decoded,
      sessionActive: !!sessionData
    });
  }

  // POST /api/auth/logout
  if ((pathname === '/api/auth/logout' || pathname === '/logout') && method === 'POST') {
    const authHeader = req.headers['authorization'];
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const decoded = verifyJWT(authHeader.substring(7), JWT_SECRET);
      if (decoded && decoded.userId) {
        await redisClient.del(`session:${decoded.userId}`);
      }
    }
    return sendJson(res, 200, { message: 'Logged out successfully' });
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
