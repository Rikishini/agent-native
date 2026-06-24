# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Agent-Native — generic Railway/Docker build
# Pass BUILD_APP=<template-name> to choose which template to serve.
# Default: dispatch (the mission-control app — best starting point).
# ─────────────────────────────────────────────────────────────────────────────

FROM node:24-slim AS builder
ARG BUILD_APP=dispatch
WORKDIR /app

# Native-module build tools (better-sqlite3, canvas, node-pty, etc.)
RUN apt-get update && apt-get install -y \
    python3 make g++ git \
    && rm -rf /var/lib/apt/lists/*

# Activate the exact pnpm version declared in package.json#packageManager
RUN corepack enable pnpm

# Copy the full workspace so pnpm can resolve workspace:* deps
COPY . .

# Install all workspace deps.
# postinstall builds: core, shared-app-config, code-agents-ui,
# migrate, pinpoint, scheduling, embedding, dispatch packages.
RUN pnpm install --frozen-lockfile

# Build the chosen template for a long-running Node.js server.
# NITRO_PRESET=node-server produces .output/server/index.mjs
RUN NITRO_PRESET=node-server pnpm --filter "${BUILD_APP}" build

# ── Runtime image (much smaller — only the compiled output) ──────────────────
FROM node:24-slim
ARG BUILD_APP=dispatch
WORKDIR /app

COPY --from=builder /app/templates/${BUILD_APP}/.output /app/.output

# SQLite fallback lives here when DATABASE_URL is not set (dev/preview only)
RUN mkdir -p /app/data

ENV PORT=3000
EXPOSE 3000

CMD ["node", "/app/.output/server/index.mjs"]
