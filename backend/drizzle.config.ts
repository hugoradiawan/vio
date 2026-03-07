import type { Config } from 'drizzle-kit';

export default {
  schema: './src/db/schema/index.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL || 'postgresql://vio:vio@127.0.0.1:55432/vio',
  },
  verbose: true,
  strict: true,
} satisfies Config;
