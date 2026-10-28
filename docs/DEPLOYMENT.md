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
| **Backend CI** | `.github/workflows/backend-ci.yml` | Push & PR to `main` | TypeScript compile, 8 Jest test suites (57 tests) on Node.js 22 LTS with MongoDB service container |

### How to Download Android APK Artifact
1. Push commits to `main` or trigger manually from the GitHub Actions tab.
2. Select the run under **Flutter Android Build**.
3. Under the **Artifacts** section at the bottom of the page, click **`tradeverse-mobile-debug-apk`**.
4. Transfer and install the `.apk` directly onto any physical Android device (API 24+).

---

## 3. Production Environment Configuration

Configure the following environment variables on your cloud hosting platform (Render, AWS ECS, GCP Cloud Run, Railway, or Fly.io):

| Variable | Description | Production Example |
| :--- | :--- | :--- |
| `PORT` | HTTP/WebSocket listening port | `5000` |
| `NODE_ENV` | Runtime environment | `production` |
| `MONGODB_URI` | MongoDB Atlas replica-set connection string | `mongodb+srv://app_user:<pass>@cluster0.mongodb.net/tradeverse?retryWrites=true&w=majority` |
| `JWT_ACCESS_SECRET` | 64-byte high-entropy key for signing access tokens | `openssl rand -hex 32` |
| `JWT_REFRESH_SECRET`| 64-byte high-entropy key for signing refresh tokens | `openssl rand -hex 32` |
| `CORS_ORIGINS` | Permitted origins (comma-separated, no wildcards in prod) | `https://app.tradeverse.ai,https://admin.tradeverse.ai` |
| `STARTING_CAPITAL` | Fictional capital allocated to newly registered accounts | `1000000` (₹10 Lakhs) |
| `GEMINI_API_KEY` | Google Gemini API key for AI assistant & news analysis | `AIzaSy...` (optional; falls back to deterministic engine) |
| `MARKET_DATA_PROVIDER_KEY` | External quote stream provider token | Optional |

---

## 4. MongoDB Atlas Indexing & Backup Recommendations

### Recommended Database Indexes
Execute these index definitions to ensure sub-millisecond query performance under production loads:

```javascript
// 1. Users Collection
db.users.createIndex({ email: 1 }, { unique: true });

// 2. Paper Accounts Collection
db.paperaccounts.createIndex({ userId: 1 }, { unique: true });

// 3. Orders Collection
db.orders.createIndex({ userId: 1, createdAt: -1 });
db.orders.createIndex({ userId: 1, status: 1 });
db.orders.createIndex({ idempotencyKey: 1 }, { unique: true, sparse: true });
db.orders.createIndex({ status: 1, triggerPrice: 1 }); // For trigger engine polling

// 4. Positions & Holdings Collection
db.positions.createIndex({ userId: 1, symbol: 1, product: 1 }, { unique: true });

// 5. Ledger Entries Collection (Immutable Audit Trail)
db.ledgerentries.createIndex({ userId: 1, createdAt: -1 });
db.ledgerentries.createIndex({ referenceId: 1 });

// 6. Refresh Tokens Collection (Session Security)
db.refreshtokens.createIndex({ tokenHash: 1 }, { unique: true });
db.refreshtokens.createIndex({ userId: 1, revoked: 1 });
db.refreshtokens.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 }); // Automatic TTL expiration

// 7. Community Messages Collection
db.communitymessages.createIndex({ roomId: 1, createdAt: -1 });

// 8. Watchlists Collection
db.watchlists.createIndex({ userId: 1, isDefault: 1 });
```

### Backup & Disaster Recovery Strategy
1. **Continuous Cloud Backups**: Enable MongoDB Atlas Continuous Cloud Backups (Point-in-Time Recovery) with a 7-day granular recovery window.
2. **Scheduled Snapshots**: Configure daily automated snapshots with a 30-day retention schedule and monthly snapshots with 1-year retention.
3. **Cross-Region Snapshot Copying**: Replicate snapshots to a secondary cloud region (e.g., AWS Mumbai `ap-south-1` to Singapore `ap-southeast-1`) for disaster resilience.
4. **Recovery Objectives**:
   - **RPO (Recovery Point Objective)**: < 1 minute (via Atlas oplog PITR).
   - **RTO (Recovery Time Objective)**: < 15 minutes to provision a replacement restored cluster.

---

## 5. Health Check Probes & Monitoring

The API exposes standard Kubernetes/Cloud Run health probes:

- **Liveness Probe**: `GET /health/liveness`
  - Returns `200 OK` with `{ status: 'live', uptime: <seconds> }`. Used by orchestrators to determine if the container needs restart.
- **Readiness Probe**: `GET /health/readiness`
  - Returns `200 OK` with `{ status: 'ready', database: 'connected' }`. Used to determine if the container is ready to accept user traffic.
- **Diagnostics**: `GET /health`
  - Returns subsystem operational status, software version, and environment.

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
