import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import mongoose from 'mongoose';
import { createApp } from './app';
import { config } from './config';

async function bootstrap() {
  const app = createApp();
  const server = http.createServer(app);

  // Initialize Socket.IO
  const io = new SocketIOServer(server, {
    cors: { origin: config.corsOrigin, methods: ['GET', 'POST'] }
  });

  io.on('connection', (socket) => {
    console.log(`[Socket.IO] Client connected: ${socket.id}`);

    socket.on('join_ticker', (data) => {
      console.log(`[Socket.IO] ${socket.id} subscribed to symbols:`, data?.symbols);
    });

    socket.on('disconnect', () => {
      console.log(`[Socket.IO] Client disconnected: ${socket.id}`);
    });
  });

  // Attempt MongoDB connection if configured
  if (config.mongoUri && !config.mongoUri.includes('127.0.0.1')) {
    try {
      await mongoose.connect(config.mongoUri);
      console.log('Connected to MongoDB Atlas');
    } catch (err) {
      console.warn('MongoDB connection warning:', (err as Error).message);
    }
  }

  server.listen(config.port, () => {
    console.log(`TradeVerse AI API running on http://localhost:${config.port} (env: ${config.nodeEnv})`);
  });
}

if (process.env.NODE_ENV !== 'test') {
  bootstrap();
}
