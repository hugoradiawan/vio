import { SQL } from 'bun';
import { drizzle } from 'drizzle-orm/bun-sql';
import * as schema from './schema';

const connectionString = process.env.DATABASE_URL || 'postgresql://vio:vio@localhost:5432/vio';

// Bun native SQL client
const client = new SQL(connectionString);
export const db = drizzle({ client, schema });

// Export schema for use in other files
export { schema };
