// First-boot admin for Paperless-AI on Railway.
// Upstream's setup wizard lets the first visitor create the admin account. On a public Railway
// URL that would be a stranger, so this creates the admin from ADMIN_USERNAME / ADMIN_PASSWORD
// before the server starts. It does nothing once any account exists (change the password in the
// web interface afterwards; the variable is only read on the first boot).
import path from 'node:path';
import { AppContext } from '/app/dist/server/context.js';
import { hashPassword, validatePassword } from '/app/dist/server/auth.js';

const dataDir = path.resolve(process.env.PAPERLESS_AI_DATA_DIR || '/app/data');
const username = (process.env.ADMIN_USERNAME || 'admin').trim();
const password = process.env.ADMIN_PASSWORD || '';

const ctx = new AppContext({ dataDir });
try {
  if (ctx.repos.users.count() > 0) {
    console.log('[railway] accounts exist, admin bootstrap skipped');
  } else {
    const problem = validatePassword(password);
    if (problem) {
      console.error(`[railway] ADMIN_PASSWORD: ${problem}. Set ADMIN_PASSWORD on the Railway service and redeploy.`);
      process.exitCode = 1;
    } else {
      const hash = await hashPassword(password);
      if (ctx.repos.users.count() === 0) {
        ctx.repos.users.create(username.slice(0, 100), hash, 'admin');
        console.log(`[railway] created admin account "${username}" (password: the ADMIN_PASSWORD variable)`);
      }
    }
  }
} finally {
  ctx.close();
}
