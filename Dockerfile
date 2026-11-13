# Multi-stage Dockerfile for Next.js (Standalone output)

# ------------------------------------------------------------------------------
# Stage 1: Install Dependencies
# ------------------------------------------------------------------------------
FROM node:20-alpine AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies strictly using package-lock.json
COPY package.json package-lock.json ./
RUN npm ci

# ------------------------------------------------------------------------------
# Stage 2: Build Application
# ------------------------------------------------------------------------------
FROM node:20-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# In Next.js, NEXT_PUBLIC_* variables are inlined into client JS at build time.
# Railway passes service variables during build.
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_FILE_URL
ARG NEXT_PUBLIC_PROMO_COUPON
ARG NEXT_PUBLIC_NOMINATIM_CONTACT

ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_FILE_URL=$NEXT_PUBLIC_FILE_URL
ENV NEXT_PUBLIC_PROMO_COUPON=$NEXT_PUBLIC_PROMO_COUPON
ENV NEXT_PUBLIC_NOMINATIM_CONTACT=$NEXT_PUBLIC_NOMINATIM_CONTACT
ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build

# ------------------------------------------------------------------------------
# Stage 3: Production Runner
# ------------------------------------------------------------------------------
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Create a non-root user and group
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy assets and standalone artifacts
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
