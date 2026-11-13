# Frontend Deployment Guide (Next.js + Railway)

This guide walks you through deploying the Next.js frontend application to [Railway](https://railway.com) as a single service.

---

## 1. Prerequisites

- A [Railway](https://railway.com) account.
- The **Spring Boot backend** must already be deployed and its public Railway domain generated (e.g. `https://ecom-backend-production.up.railway.app`).
- Next.js 14 (App Router) with Node.js 20+ support.

---

## 2. Builder Tradeoff & Recommendation

Railway offers two primary ways to build and deploy Next.js:

| Aspect | Default Builder (Railpack / Nixpacks) | Multi-Stage Dockerfile (Standalone) |
|---|---|---|
| **Image Size** | Large (~800 MB - 1.2 GB) | Ultra-lightweight (~120 MB - 160 MB) |
| **Build Configuration** | Automatic zero-config detection | Requires Dockerfile maintenance |
| **Build Variables** | Reads Railway environment variables automatically during `next build` | Requires passing `ARG` / `ENV` in Dockerfile |
| **Startup / Cold Starts** | Standard Next.js server boot | Faster boot time and lower memory footprint |
| **Our Recommendation** | **Recommended for Railway**: Railpack is the simplest and most resilient because Railway automatically exposes service variables to `npm run build` without needing complex Docker build arguments. | Use if strict container size and memory optimization are your top priorities. |

> By default, `railway.json` is preconfigured to use **Railpack**. If you wish to use the Dockerfile standalone output instead, change `"builder": "RAILPACK"` to `"builder": "DOCKERFILE"` in `railway.json`.

---

## 3. Step-by-Step Railway Deployment

### Step 1: Open Your Railway Project
1. Open the same Railway project where your backend and PostgreSQL database are deployed.
2. Having frontend and backend in the same project keeps your services organized and allows shared variables.

### Step 2: Add the Frontend Service
1. Click **"+ Create"** (or **"New"**) -> **"GitHub Repo"**.
2. Select your repository.
3. If using a monorepo containing both backend and frontend, configure the root directory:
   - Go to **Settings** -> **Root Directory** -> set to `/frontend`.

### Step 3: Set Environment Variables BEFORE Building
> ⚠️ **CRITICAL: Next.js Inlining Rule**
> In Next.js, all environment variables prefixed with `NEXT_PUBLIC_*` are **inlined into the JavaScript bundle at build time**. They are NOT read at runtime by the user's browser.
> Therefore, you **MUST** configure these variables in the Railway dashboard **BEFORE** triggering the initial build or deployment. If you change them later, you must trigger a manual **Redeploy**.

In your frontend service's **Variables** tab, set:

| Variable | Value | Description |
|---|---|---|
| `NEXT_PUBLIC_API_URL` | `https://<backend-domain>.up.railway.app/api/v1` | Backend API URL (must include `https://` and `/api/v1`) |
| `NEXT_PUBLIC_FILE_URL` | `https://<backend-domain>.up.railway.app` | Backend URL for uploaded image files (no trailing slash) |
| `NEXT_PUBLIC_PROMO_COUPON` | `WELCOME10` | Default coupon code displayed at checkout |
| `NEXT_PUBLIC_NOMINATIM_CONTACT` | `admin@ecom.com` | Optional email for OpenStreetMap reverse geocoding |

### Step 4: Generate a Public Domain
1. In the frontend service, navigate to **Settings** -> **Networking** -> **Public Networking**.
2. Click **"Generate Domain"** (e.g. `ecom-frontend-production.up.railway.app`).

### Step 5: Link Frontend Domain to Backend CORS
1. Copy the frontend public domain generated in Step 4 (e.g. `https://ecom-frontend-production.up.railway.app`).
2. Go to your **Backend Service** -> **Variables**.
3. Set `FRONTEND_URL` to this exact URL (without trailing slash).
4. Click **Redeploy** on the backend service so that Spring Boot's CORS filter recognizes the frontend domain.

### Step 6: Verify Deployment
1. Verify the frontend health check endpoint:
   ```
   https://<your-frontend-domain>.up.railway.app/api/health
   ```
   Expected response:
   ```json
   {"status":"ok","timestamp":"..."}
   ```
2. Open the main frontend URL in your browser:
   ```
   https://<your-frontend-domain>.up.railway.app
   ```
   Verify:
   - Product catalog loads data from the backend.
   - Product images render properly.
   - Admin login works with seed credentials (`admin@ecom.com / Admin@123`).

---

## 4. Backend Integration Architectures

There are two primary ways the frontend connects to the backend:

### Option A: Direct Client-to-Backend Calls (Default Architecture)
- The browser calls `NEXT_PUBLIC_API_URL` directly.
- **Requirement**: The backend must have `FRONTEND_URL` configured to allow this frontend's domain in CORS headers.
- **Advantage**: Bypasses the Next.js server for data transfers, reducing Next.js memory and CPU load.

### Option B: Server-Side Next.js Proxy / Rewrites
- If you prefer not to expose backend URLs directly or wish to bypass browser CORS restrictions:
- In `next.config.mjs`, rewrites are pre-configured to forward `/api/proxy/:path*` to `process.env.BACKEND_URL`.
- You can set `BACKEND_URL=http://backend.railway.internal:8080` (using Railway private networking) and point `NEXT_PUBLIC_API_URL=/api/proxy`.

---

## 5. Troubleshooting

### 1. Build Failures (e.g., `Type error`, `Cannot find module`)
- **Cause**: Missing devDependencies or uncommitted files.
- **Fix**: The build runs `next build`. Ensure all dependencies are present in `package.json`. In the build log, inspect the specific error. The `engines` field in `package.json` specifies Node `>=20.0.0 <23.0.0` to match Railway's build environment.

### 2. Port Binding Errors
- **Symptom**: Railway log displays `Application failed to respond` or container exits immediately.
- **Cause**: Next.js listening on hardcoded port 3000 instead of Railway's `$PORT`.
- **Fix**: The start script in `package.json` is configured as:
  ```json
  "start": "next start -p $PORT -H 0.0.0.0"
  ```
  Binding to `0.0.0.0` and using `$PORT` ensures Railway's edge proxy routes traffic properly.

### 3. Wrong Node Version
- **Symptom**: Build fails due to unsupported JavaScript/Node syntax.
- **Fix**: We pinned `"engines": { "node": ">=20.0.0 <23.0.0" }` in `package.json`. Railpack uses this field to provision Node 20 LTS.

### 4. Environment Variables Not Applied
- **Symptom**: The browser still makes API calls to `http://localhost:8080/api/v1`.
- **Cause**: `NEXT_PUBLIC_API_URL` was added after the build ran.
- **Fix**: Next.js bakes `NEXT_PUBLIC_*` variables into static files during the build phase. Whenever you add or edit these variables in the Railway dashboard, you **must trigger a redeploy** for the changes to take effect.

### 5. CORS Errors in Browser Console
- **Symptom**: `Access to fetch at 'https://.../api/v1/...' from origin 'https://...' has been blocked by CORS policy`.
- **Cause**: The backend's `FRONTEND_URL` variable does not match the frontend's origin or contains a trailing slash.
- **Fix**:
  1. Ensure `FRONTEND_URL` on the backend service exactly matches `https://<frontend-domain>.up.railway.app` (no trailing slash).
  2. Redeploy the backend service.

---

## 6. Manual Railway Dashboard Checklist

1. [ ] Deploy the backend service and database first.
2. [ ] Generate public domain on backend service (e.g., `https://backend.up.railway.app`).
3. [ ] Add frontend service from GitHub repo (set Root Directory to `/frontend` if in a monorepo).
4. [ ] In frontend service **Variables**, add:
   - `NEXT_PUBLIC_API_URL=https://<backend-domain>.up.railway.app/api/v1`
   - `NEXT_PUBLIC_FILE_URL=https://<backend-domain>.up.railway.app`
   - `NEXT_PUBLIC_PROMO_COUPON=WELCOME10`
5. [ ] Deploy frontend and generate its public domain (e.g., `https://frontend.up.railway.app`).
6. [ ] Copy frontend domain into backend's `FRONTEND_URL` variable and redeploy the backend.
7. [ ] Visit `/api/health` and verify home page loads data correctly.
