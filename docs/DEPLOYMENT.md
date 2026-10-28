# TradeVerse AI — Production Deployment & Cloud Infrastructure Guide

## 1. Zero-Local-Flutter Paradigm

In accordance with strict environment constraints:
- **No local Flutter, Dart SDK, or Android Studio is required on the developer workstation.**
- All dependency resolution, static analysis, unit tests, widget tests, and Android APK / AAB compilation occur strictly in **GitHub Actions cloud runners**.

---

## 2. GitHub Actions CI/CD Workflows

The repository includes three automated cloud workflows:

| Workflow | File | Triggers | Artifacts Generated |
| :--- | :--- | :--- | :--- |
| **Flutter CI** | `.github/workflows/flutter-ci.yml` | Push & PR to `main` | Format check, Static Analysis (`strict-casts`, `strict-inference`), Unit & Widget tests |
| **Flutter Android Build** | `.github/workflows/flutter-android-build.yml` | Push to `main`, Manual dispatch | `tradeverse-mobile-debug-apk` (`app-debug.apk`) |
| **Backend CI** | `.github/workflows/backend-ci.yml` | Push & PR to `main` | TypeScript compile, 11 Jest test suites (82 tests) on Node.js 22 LTS with MongoDB service container |

### How to Download Android APK Artifact
1. Push commits to `main` or trigger manually from the GitHub Actions tab.
2. Select the run under **Flutter Android Build**.
3. Under the **Artifacts** section at the bottom of the page, click **`tradeverse-mobile-debug-apk`**.
4. Transfer and install the `.apk` directly onto any physical Android device (API 24+).

---

## 3. Hosting on Render (render.com) — Step-by-Step Guide

TradeVerse AI is fully configured for automated cloud deployment to **Render** using the included `render.yaml` Blueprint or as a manual Web Service.

### Option A: Automated Blueprint Deployment (Recommended)

1. Sign in to your [Render Dashboard](https://dashboard.render.com/).
2. Click **New +** → **Blueprint**.
3. Connect and select your GitHub repository: `Abhinavkunnummal/VirtualTradingApp`.
4. Render detects `render.yaml` at the root and presents the **`tradeverse-api`** service configuration:
   - **Runtime**: Node.js
   - **Root Directory**: `apps/api`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `node dist/server.js`
   - **Health Check Path**: `/health`
5. Render prompts you for your `MONGODB_URI`:
   - Enter your MongoDB Atlas connection string (e.g., `mongodb+srv://<user>:<password>@cluster0.mongodb.net/tradeverse?retryWrites=true&w=majority`).
6. Click **Apply**. Render will generate high-entropy secrets for `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` automatically and provision the service.

---

### Option B: Manual Web Service Setup

If you prefer configuring the Web Service manually:

1. In the Render Dashboard, click **New +** → **Web Service**.
2. Select your repository: `Abhinavkunnummal/VirtualTradingApp`.
3. Configure the service settings:
   - **Name**: `tradeverse-api`
   - **Region**: Choose the closest region to your users (e.g., `Singapore`, `Frankfurt`, or `Oregon`)
   - **Branch**: `main`
   - **Root Directory**: `apps/api`
   - **Runtime**: `Node`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `node dist/server.js`
   - **Instance Type**: `Free`
4. Expand **Advanced** and set **Health Check Path** to `/health`.
5. Under **Environment Variables**, add:

| Variable | Description | Example / Recommended Value |
| :--- | :--- | :--- |
| `NODE_ENV` | Production environment mode | `production` |
| `PORT` | Listening port (Render default is 10000) | `10000` |
| `MONGODB_URI` | MongoDB Atlas replica-set connection string | `mongodb+srv://<user>:<password>@cluster0.mongodb.net/tradeverse?retryWrites=true&w=majority` |
| `JWT_ACCESS_SECRET` | Secret key for signing access tokens (min 32 chars) | `openssl rand -hex 32` |
| `JWT_REFRESH_SECRET`| Secret key for signing refresh tokens (min 32 chars) | `openssl rand -hex 32` |
| `CORS_ORIGINS` | Permitted origins | `*` |
| `STARTING_CAPITAL` | Fictional sandbox balance for new accounts | `1000000` (₹10 Lakhs) |

6. Click **Create Web Service**.

---

### Step 4: MongoDB Atlas IP Access List
In your [MongoDB Atlas Console](https://cloud.mongodb.com/):
1. Navigate to **Network Access** → **IP Access List**.
2. Click **Add IP Address**.
3. Select **Allow Access from Anywhere** (`0.0.0.0/0`) or configure Render's outbound IP addresses.
4. Ensure your database user credentials in `MONGODB_URI` have Read and Write privileges on the `tradeverse` database.

---

### Step 5: Verify Health
Once Render finishes deploying:
1. Copy your public service URL from the dashboard (e.g. `https://tradeverse-api.onrender.com`).
2. Test health verification in your browser or terminal:
   ```bash
   curl https://tradeverse-api.onrender.com/health
   ```
   Expected response:
   ```json
   {
     "status": "healthy",
     "version": "1.0.0",
     "services": {
       "database": "configured",
       "paperEngine": "active",
       "marketData": "active"
     }
   }
   ```

> **Note on Render Free Tier:** Render free instances spin down after 15 minutes of inactivity. When a new request arrives, Render automatically spins up the instance (cold start ~30s). The Flutter mobile app's Dio client is configured with a 30-second `connectTimeout` to handle cold starts seamlessly.

---

### Step 6: Connect Flutter Mobile App to Render Backend
To point the mobile app to your Render backend, compile the APK in GitHub Actions with:
```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://<your-render-service>.onrender.com/api/v1
```
The mobile application will seamlessly target your live cloud API server.

---

## 4. Production Environment Configuration Reference

| Variable | Description | Production Example |
| :--- | :--- | :--- |
| `PORT` | HTTP/WebSocket listening port | `5000` |
| `NODE_ENV` | Runtime environment | `production` |
| `MONGODB_URI` | MongoDB Atlas connection string | `mongodb+srv://app_user:<pass>@cluster0.mongodb.net/tradeverse?retryWrites=true&w=majority` |
| `JWT_ACCESS_SECRET` | 64-byte high-entropy key for signing access tokens | `openssl rand -hex 32` |
| `JWT_REFRESH_SECRET`| 64-byte high-entropy key for signing refresh tokens | `openssl rand -hex 32` |
| `CORS_ORIGINS` | Permitted origins | `*` |
| `STARTING_CAPITAL` | Fictional capital allocated to newly registered accounts | `1000000` (₹10 Lakhs) |
| `GEMINI_API_KEY` | Google Gemini API key for AI assistant & news analysis | Optional; fallback to deterministic engine |

---

## 5. MongoDB Atlas Indexing & Backup Recommendations

### Recommended Database Indexes
Execute these index definitions to ensure sub-millisecond query performance under production loads:

```javascript
// 1. Users Collection
db.users.createIndex({ email: 1 }, { unique: true });

// 2. Paper Accounts Collection
db.paperaccounts.createIndex({ userId: 1 }, { unique: true });

// 3. Orders Collection (Regular, Bracket, Cover & Child Legs)
db.orders.createIndex({ userId: 1, createdAt: -1 });
db.orders.createIndex({ userId: 1, status: 1 });
db.orders.createIndex({ idempotencyKey: 1 }, { unique: true, sparse: true });
db.orders.createIndex({ parentOrderId: 1 });
db.orders.createIndex({ symbol: 1, status: 1 }); // For tick-matching & trailing stop evaluation

// 4. Holdings Collection
db.holdings.createIndex({ paperAccountId: 1, instrumentId: 1 }, { unique: true });
db.holdings.createIndex({ userId: 1, symbol: 1 });

// 5. Ledger Entries Collection (Immutable Audit Trail)
db.ledgerentries.createIndex({ userId: 1, createdAt: -1 });
db.ledgerentries.createIndex({ orderId: 1 });

// 6. In-App Notifications Collection
db.notifications.createIndex({ userId: 1, createdAt: -1 });
db.notifications.createIndex({ userId: 1, read: 1 });

// 7. Refresh Sessions Collection (Session Security)
db.refreshsessions.createIndex({ tokenHash: 1 }, { unique: true });
db.refreshsessions.createIndex({ userId: 1, revoked: 1 });
db.refreshsessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 }); // Automatic TTL expiration

// 8. Community Messages Collection
db.communitymessages.createIndex({ roomId: 1, createdAt: -1 });

// 9. Watchlists Collection
db.watchlists.createIndex({ userId: 1, isDefault: 1 });
```

---

## 6. Process Lifecycle & Graceful Shutdown

TradeVerse AI listens for `SIGTERM` and `SIGINT` OS signals to shut down gracefully:

```
Process receives SIGTERM
  │
  ├─ 1. Stops accepting new HTTP requests & WebSocket handshakes
  ├─ 2. Closes existing HTTP Keep-Alive connections
  ├─ 3. Disconnects active Socket.IO clients cleanly
  ├─ 4. Awaits pending in-flight database transactions
  ├─ 5. Closes Mongoose connection pool
  └─ 6. Exits cleanly with code 0 (10s timeout safety guard)
```

---

## 7. Security Hardening Summary

1. **Helmet.js**: Sets secure HTTP response headers (`X-Content-Type-Options`, `Strict-Transport-Security`, `X-Frame-Options`).
2. **Strict Rate Limiting**: Global limit of 2,000 requests per 15-minute window; tightened limits on `/auth/login` and `/auth/register` to prevent credential stuffing.
3. **Refresh Token Compromise Detection**: Invalidation of all family sessions upon detection of token replay.
4. **WebSocket Channel Boundaries**: Regex validation restricting room subscriptions and isolating private user updates to `user:<userId>`.
5. **Prompt Injection Guardrails**: Strict 200-character input bounds, delimiter stripping, and blocklists defending the AI assistant against jailbreaks.
6. **Error Redaction**: Internal database errors and stack traces are suppressed in production mode to prevent information disclosure.
