#!/usr/bin/env bash
# Generate OpenAPI schema from a NestJS project using SwaggerModule.
set -euo pipefail

OUTPUT="${1:?Usage: nestjs.sh <output_path>}"
mkdir -p "$(dirname "$OUTPUT")"

# Install dependencies
echo "[drift-agent] installing NestJS dependencies..."
if [ -f "pnpm-lock.yaml" ]; then
  pnpm install --frozen-lockfile --prefer-offline 2>/dev/null || pnpm install
elif [ -f "yarn.lock" ]; then
  yarn install --frozen-lockfile 2>/dev/null || yarn install
else
  npm ci 2>/dev/null || npm install
fi

# Write the generation script INTO the project directory so Node resolves
# reflect-metadata and @nestjs/* from the project's own node_modules.
cat > ./.drift-nestjs-gen.ts << 'GENEOF'
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import * as fs from 'fs';
import * as path from 'path';

const OUTPUT = process.env.DRIFT_OUTPUT!;

async function generate() {
  const candidates = [
    './src/app.module',
    './src/app/app.module',
    './app.module',
    './app/app.module',
  ];

  let AppModule: any;
  for (const p of candidates) {
    try {
      AppModule = (await import(path.resolve(p))).AppModule;
      if (AppModule) break;
    } catch {}
  }

  if (!AppModule) {
    console.error('[drift-agent] AppModule not found — tried:', candidates.join(', '));
    process.exit(1);
  }

  const app = await NestFactory.create(AppModule, { logger: false });
  const config = new DocumentBuilder()
    .setTitle('API')
    .setVersion('1.0')
    .build();
  const doc = SwaggerModule.createDocument(app, config);
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, JSON.stringify(doc, null, 2));
  console.log(`[drift-agent] generated NestJS OpenAPI schema → ${OUTPUT}`);
  await app.close();
}

generate().catch(e => {
  console.error('[drift-agent] NestJS schema generation failed:', e.message);
  process.exit(1);
});
GENEOF

# Run from within the project directory so module resolution uses project node_modules
DRIFT_OUTPUT="$OUTPUT" npx ts-node \
  --project tsconfig.json \
  --transpile-only \
  ./.drift-nestjs-gen.ts

EXIT_CODE=$?
rm -f ./.drift-nestjs-gen.ts

if [ $EXIT_CODE -ne 0 ]; then
  echo "::error::NestJS schema generation failed. Check that AppModule can be imported and @nestjs/swagger is installed." >&2
  exit 1
fi
