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

## 3. Hosting on Railway (Step-by-Step Guide)

TradeVerse AI is fully pre-configured for instant zero-configuration deployment to **Railway** using the included `railway.json` and multi-stage `Dockerfile`.

### Step 1: Create a Project on Railway
1. Sign in to your [Railway Dashboard](https://railway.com/).
2. Click **New Project** → **Deploy from GitHub repo**.
3. Select your repository: `Abhinavkunnummal/VirtualTradingApp`.

### Step 2: Automatic Dockerfile Build
Railway automatically detects `railway.json` located at the root of the repository:
- Builder: `DOCKERFILE` (`apps/api/Dockerfile`)
- Start command: `node dist/server.js`
- Automated Healthcheck Probe: `/health` (120s timeout)
- Restart policy: `ON_FAILURE` (max 5 retries)

### Step 3: Configure Environment Variables in Railway
In your Railway Service dashboard, open the **Variables** tab and add the following:

| Variable | Description | Example / Recommended Value |
| :--- | :--- | :--- |
| `NODE_ENV` | Production environment mode | `production` |
| `MONGODB_URI` | MongoDB Atlas replica-set connection string | `mongodb+srv://<user>:<password>@cluster0.mongodb.net/tradeverse?retryWrites=true&w=majority` |
| `JWT_ACCESS_SECRET` | 64-byte secret key for signing access tokens | `tradeverse_production_access_secret_key_minimum_32_chars_long!` |
| `JWT_REFRESH_SECRET`| 64-byte secret key for signing refresh tokens | `tradeverse_production_refresh_secret_key_minimum_32_chars_long!` |
| `CORS_ORIGINS` | Permitted origins | `*` (or your custom domain) |
| `STARTING_CAPITAL` | Fictional sandbox balance for new users | `1000000` (₹10 Lakhs) |

> **Note on PORT:** Railway automatically injects the `$PORT` environment variable at runtime. The TradeVerse configuration parses this string automatically.

### Step 4: MongoDB Atlas IP Access List
In your [MongoDB Atlas Console](https://cloud.mongodb.com/):
1. Navigate to **Network Access** → **IP Access List**.
2. Click **Add IP Address**.
3. Select **Allow Access from Anywhere** (`0.0.0.0/0`) or configure Railway's static outbound IP addresses.
4. Ensure your database user credentials in `MONGODB_URI` have Read and Write privileges on the `tradeverse` database.

### Step 5: Generate Public Domain
1. In the Railway Service dashboard, open the **Settings** tab.
2. Scroll to **Networking** → **Public Networking**.
3. Click **Generate Domain** (e.g. `virtualtradingapp-production.up.railway.app`).
4. Test health verification in your browser:
   ```bash
   curl https://<your-railway-domain>.up.railway.app/health
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

### Step 6: Connect Flutter Mobile App to Railway Backend
To point the mobile app to your Railway deployment, compile the APK in GitHub Actions with:
```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://<your-railway-domain>.up.railway.app/api/v1
```
The mobile application will seamlessly target your cloud API server.

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
