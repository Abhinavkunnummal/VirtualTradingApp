import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  PORT: z.string().default('5000').transform((v) => parseInt(v, 10)),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  MONGODB_URI: z.string().default('mongodb://127.0.0.1:27017/tradeverse'),
  JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 characters long').default('tradeverse_dev_jwt_access_secret_key_32_chars_minimum!'),
  JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be at least 32 characters long').default('tradeverse_dev_jwt_refresh_secret_key_32_chars_minimum!'),
  CORS_ORIGINS: z.string().default('*'),
  STARTING_CAPITAL: z.string().default('1000000').transform((v) => parseFloat(v)),
});

const parsedEnv = envSchema.safeParse(process.env);

if (!parsedEnv.success) {
  console.error('[Config Error] Invalid environment configuration:');
  parsedEnv.error.issues.forEach((issue) => {
    console.error(` - ${issue.path.join('.')}: ${issue.message}`);
  });
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Fatal: Invalid production environment configuration');
  }
}

const env = parsedEnv.success ? parsedEnv.data : envSchema.parse({});

export const config = {
  port: env.PORT,
  nodeEnv: env.NODE_ENV,
  mongoUri: env.MONGODB_URI,
  jwtAccessSecret: env.JWT_ACCESS_SECRET,
  jwtRefreshSecret: env.JWT_REFRESH_SECRET,
  corsOrigins: env.CORS_ORIGINS,
  startingCapital: env.STARTING_CAPITAL,
  isProduction: env.NODE_ENV === 'production',
  isTest: env.NODE_ENV === 'test',
};
