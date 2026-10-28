import http from 'http';
import { Server as SocketIOServer } from 'socket.io';
import mongoose from 'mongoose';
import { createApp } from './app';
import { config } from './config';
import { SocketService } from './services/socket.service';

async function bootstrap() {
  const app = createApp();
  const server = http.createServer(app);

  // Initialize Socket.IO with centralized service
  const io = new SocketIOServer(server, {
    cors: { origin: config.corsOrigins, methods: ['GET', 'POST'] },
  });

  SocketService.init(io);

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

  const shutdown = async (signal: string) => {
    console.log(`Received ${signal}. Initiating graceful shutdown...`);
    server.close(async () => {
      console.log('HTTP and WebSocket server closed.');
      if (mongoose.connection.readyState !== 0) {
        await mongoose.connection.close();
        console.log('MongoDB connection closed.');
      }
      process.exit(0);
    });

    setTimeout(() => {
      console.error('Forced shutdown due to 10s timeout.');
      process.exit(1);
    }, 10000).unref();
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

if (process.env.NODE_ENV !== 'test') {
  bootstrap();
}
