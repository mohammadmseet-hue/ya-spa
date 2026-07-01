// Copies the Ya Spa static web files into ./www so Capacitor can bundle them
// into the native iOS/Android app, and injects the app-only layers:
//   • native.js  (always)  — status bar, push, back button, share
//   • checkout   (only if app/checkout/config.js exists) — in-app card/Apple Pay
// The public website is never modified — these live only inside the app bundle.
import { cp, rm, mkdir, readFile, writeFile, access } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const scriptDir = dirname(fileURLToPath(import.meta.url)); // app/scripts
const appDir    = join(scriptDir, '..');                   // app
const webRoot   = join(appDir, '..');                      // Ya Spa site root
const www       = join(appDir, 'www');

const exists = (p) => access(p).then(() => true).catch(() => false);

const INCLUDE = ['index.html', 'deck.html', 'compliance.html', 'paid.html', 'assets'];

await rm(www, { recursive: true, force: true });
await mkdir(www, { recursive: true });

for (const item of INCLUDE) {
  try {
    await cp(join(webRoot, item), join(www, item), { recursive: true });
    console.log(`  + ${item}`);
  } catch (e) {
    console.warn(`  ! skipped ${item}: ${e.message}`);
  }
}

// --- native layer (always) ---
await cp(join(appDir, 'native', 'native.js'), join(www, 'native.js'));
const injects = ['<script src="native.js"></script>'];

// --- payments (only when configured with a real config.js) ---
if (await exists(join(appDir, 'checkout', 'config.js'))) {
  await mkdir(join(www, 'checkout'), { recursive: true });
  await cp(join(appDir, 'checkout', 'config.js'),   join(www, 'checkout', 'config.js'));
  await cp(join(appDir, 'checkout', 'checkout.js'), join(www, 'checkout', 'checkout.js'));
  injects.unshift('<script src="checkout/config.js"></script>', '<script src="checkout/checkout.js"></script>');
  console.log('  + checkout (payments enabled)');
} else {
  console.log('  · checkout skipped (no app/checkout/config.js yet — WhatsApp-only build)');
}

// inject scripts right before </body> of the bundled index.html
const indexPath = join(www, 'index.html');
let html = await readFile(indexPath, 'utf8');
html = html.replace('</body>', '  ' + injects.join('\n  ') + '\n</body>');
await writeFile(indexPath, html);

console.log('✓ Ya Spa web assets copied to app/www (+ native layer' +
            (injects.length > 1 ? ' + payments' : '') + ')');
