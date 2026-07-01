#!/usr/bin/env node
/**
 * Build script that runs TypeScript and Vite, then copies .htaccess to dist
 * This ensures the .htaccess file is never lost during builds
 */

import { execSync } from 'child_process';
import { copyFileSync, existsSync } from 'fs';
import { resolve } from 'path';

try {
  console.log('🔨 Building admin panel...');

  // Run the actual build
  execSync('tsc -b && vite build', { stdio: 'inherit' });

  // Copy .htaccess to dist directory
  const htaccessSource = resolve('./.htaccess');
  const htaccessDest = resolve('./dist/.htaccess');

  if (existsSync(htaccessSource)) {
    copyFileSync(htaccessSource, htaccessDest);
    console.log('✅ .htaccess copied to dist/');
  } else {
    console.warn('⚠️  .htaccess file not found in admin-panel root');
  }

  console.log('✅ Build complete!');
} catch (error) {
  console.error('❌ Build failed:', error.message);
  process.exit(1);
}
