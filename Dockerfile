# Multi-stage build: compile n8n from monorepo, then run
# Build: docker build -t n8n:local .
# Run:  docker run -p 5678:5678 n8n:local

ARG NODE_VERSION=24.13.1

# -----------------------------------------------------------------------------
# Stage 1: build n8n (pnpm install, build, deploy to ./compiled)
# -----------------------------------------------------------------------------
FROM node:${NODE_VERSION}-alpine AS builder

ARG NODE_VERSION
RUN apk add --no-cache libc6-compat

WORKDIR /app

# Enable pnpm (match packageManager in package.json)
RUN corepack enable && corepack prepare pnpm@10.22.0 --activate

# Copy full repo (build-n8n.mjs runs install, build, trim, deploy)
COPY . .

# Install deps, build janitor so its bin (dist/cli.js) exists before build-n8n.mjs, then run full build
ENV NODE_ENV=production
ENV CI=true
RUN corepack enable && corepack prepare pnpm@10.22.0 --activate && \
    pnpm install --frozen-lockfile && \
    (cd packages/testing/janitor && pnpm run build) && \
    N8N_SKIP_LICENSES=true node scripts/build-n8n.mjs

# -----------------------------------------------------------------------------
# Stage 2: runtime image with n8n from compiled/
# -----------------------------------------------------------------------------
FROM node:${NODE_VERSION}-alpine AS runner

ARG NODE_VERSION
ENV NODE_ENV=production
ENV N8N_RELEASE_TYPE=dev
ENV SHELL=/bin/sh

# Runtime deps + build deps for native sqlite3; python3+aws-cli for optional S3 .env loading
RUN apk add --no-cache \
    tini \
    tzdata \
    ca-certificates \
    libc6-compat \
    python3 \
    py3-pip \
    make \
    g++ \
    git \
    openssh \
    openssl \
    graphicsmagick \
    && pip3 install --break-system-packages --no-cache-dir awscli \
    && apk del py3-pip

WORKDIR /home/node

COPY --from=builder /app/compiled /usr/local/lib/node_modules/n8n
COPY docker/images/n8n/docker-entrypoint.sh /

RUN cd /usr/local/lib/node_modules/n8n && \
    npm rebuild sqlite3 && \
    apk del make g++ && \
    ln -sf /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node && \
    rm -rf /root/.npm /tmp/*

EXPOSE 5678/tcp
USER node
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

LABEL org.opencontainers.image.title="n8n" \
      org.opencontainers.image.description="Workflow Automation Tool" \
      org.opencontainers.image.source="https://github.com/n8n-io/n8n"
