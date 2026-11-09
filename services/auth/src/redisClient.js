/**
 * Pure Node.js Redis Client (Zero external npm dependencies)
 * Implements Redis RESP protocol over native TCP socket.
 */
const net = require('net');

const REDIS_HOST = process.env.REDIS_HOST || '127.0.0.1';
const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379', 10);
const REDIS_PASSWORD = process.env.REDIS_PASSWORD || null;

class NativeRedisClient {
  constructor(host, port) {
    this.host = host;
    this.port = port;
    this.socket = null;
    this.connected = false;
    this.inMemoryFallback = new Map();
    this.callbacks = [];
    this.connect();
  }

  connect() {
    this.socket = net.createConnection({ host: this.host, port: this.port }, () => {
      this.connected = true;
      console.log(`[Redis] Connected to ${this.host}:${this.port}`);
      if (REDIS_PASSWORD) {
        this.sendCommand(['AUTH', REDIS_PASSWORD]);
      }
    });

    this.socket.on('data', (data) => {
      this.handleResponse(data.toString());
    });

    this.socket.on('error', (err) => {
      this.connected = false;
      // Soft warning - application seamlessly falls back to memory cache
    });

    this.socket.on('close', () => {
      this.connected = false;
      setTimeout(() => this.connect(), 5000);
    });
  }

  handleResponse(data) {
    const cb = this.callbacks.shift();
    if (cb) {
      if (data.startsWith('+OK') || data.startsWith(':1')) {
        cb(null, 'OK');
      } else if (data.startsWith('$-1')) {
        cb(null, null);
      } else if (data.startsWith('$')) {
        const lines = data.split('\r\n');
        cb(null, lines[1]);
      } else {
        cb(null, data.trim());
      }
    }
  }

  sendCommand(args) {
    if (!this.connected || !this.socket) {
      return false;
    }
    try {
      let cmd = `*${args.length}\r\n`;
      for (const arg of args) {
        const str = String(arg);
        cmd += `$${Buffer.byteLength(str)}\r\n${str}\r\n`;
      }
      this.socket.write(cmd);
      return true;
    } catch (e) {
      this.connected = false;
      return false;
    }
  }

  async set(key, value, mode, ttl) {
    this.inMemoryFallback.set(key, { value, expires: ttl ? Date.now() + ttl * 1000 : null });
    if (this.connected) {
      const args = mode && ttl ? ['SET', key, value, mode, ttl] : ['SET', key, value];
      return new Promise((resolve) => {
        this.callbacks.push((err, res) => resolve(res || 'OK'));
        if (!this.sendCommand(args)) resolve('OK');
      });
    }
    return 'OK';
  }

  async get(key) {
    // Check in-memory fallback first if offline or expired
    const local = this.inMemoryFallback.get(key);
    if (local) {
      if (local.expires && Date.now() > local.expires) {
        this.inMemoryFallback.delete(key);
      } else {
        return local.value;
      }
    }

    if (this.connected) {
      return new Promise((resolve) => {
        this.callbacks.push((err, res) => resolve(res));
        if (!this.sendCommand(['GET', key])) resolve(null);
      });
    }
    return null;
  }

  async del(key) {
    this.inMemoryFallback.delete(key);
    if (this.connected) {
      return new Promise((resolve) => {
        this.callbacks.push((err, res) => resolve(res));
        if (!this.sendCommand(['DEL', key])) resolve(1);
      });
    }
    return 1;
  }

  isReady() {
    return this.connected;
  }
}

const redisClient = new NativeRedisClient(REDIS_HOST, REDIS_PORT);
module.exports = redisClient;
