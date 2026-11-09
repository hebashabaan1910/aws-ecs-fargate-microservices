/**
 * Inter-Service Communication Client (Zero External Dependencies)
 * Calls Auth Service and Notifications Service using Node.js built-in fetch().
 */
const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://auth.production.local:3000';
const NOTIFICATIONS_SERVICE_URL = process.env.NOTIFICATIONS_SERVICE_URL || 'http://notifications.production.local:3002';

async function verifyTokenWithAuthService(authHeader, traceId = '') {
  const headers = { 'Authorization': authHeader };
  if (traceId) headers['X-Amzn-Trace-Id'] = traceId;

  try {
    const res = await fetch(`${AUTH_SERVICE_URL}/api/auth/verify`, {
      method: 'GET',
      headers,
      signal: AbortSignal.timeout(5000)
    });

    const data = await res.json();
    if (!res.ok) {
      return { valid: false, error: data.error || 'Authentication rejected' };
    }
    return data;
  } catch (err) {
    console.error(`[Cloud Map Discovery Error] Failed reaching Auth at ${AUTH_SERVICE_URL}:`, err.message);
    throw new Error(`Service discovery connection to Auth failed: ${err.message}`);
  }
}

async function triggerOrderNotification(payload, traceId = '') {
  const headers = { 'Content-Type': 'application/json' };
  if (traceId) headers['X-Amzn-Trace-Id'] = traceId;

  try {
    const res = await fetch(`${NOTIFICATIONS_SERVICE_URL}/api/notifications/send`, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(5000)
    });
    return await res.json();
  } catch (err) {
    console.warn(`[Cloud Map Discovery Warning] Failed reaching Notifications at ${NOTIFICATIONS_SERVICE_URL}:`, err.message);
    return { status: 'failed', error: err.message };
  }
}

module.exports = {
  verifyTokenWithAuthService,
  triggerOrderNotification,
  AUTH_SERVICE_URL,
  NOTIFICATIONS_SERVICE_URL
};
