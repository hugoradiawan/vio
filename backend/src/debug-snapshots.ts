import { desc } from 'drizzle-orm';
import { db, schema } from './db';

const snapshots = await db.select().from(schema.snapshots).orderBy(desc(schema.snapshots.createdAt)).limit(2);
for (const s of snapshots) {
  console.log('Snapshot ID:', s.id);
  const data = s.data as { shapes?: unknown[] };
  console.log('Data keys:', Object.keys(data));
  if (data.shapes) {
    console.log('Number of shapes:', data.shapes.length);
    if (data.shapes.length > 0) {
      const firstShape = data.shapes[0] as Record<string, unknown>;
      console.log('First shape keys:', Object.keys(firstShape));
      console.log('First shape sample:', JSON.stringify(firstShape, null, 2).substring(0, 800));
    }
  }
  console.log('---');
}
process.exit(0);
