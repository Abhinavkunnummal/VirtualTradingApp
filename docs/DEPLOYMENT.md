# TradeVerse AI — Production Deployment & Cloud Infrastructure Guide

## 1. Zero-Local-Flutter Paradigm

In accordance with strict environment and developer setup constraints:
- **No local Flutter, Dart SDK, or Android Studio is required on the developer workstation.**
- All dependency resolution, static analysis, unit tests, widget tests, and Android APK / AAB compilation occur strictly in **GitHub Actions cloud runners**.
- Cloud CI automatically builds both **Debug APKs** and **Split-per-ABI Release APKs** (`armeabi-v7a`, `arm64-v8a`, `x86_64`) and publishes them to GitHub Releases.

---

## 2. GitHub Actions CI/CD Workflows

The repository includes three automated cloud workflows:

| Workflow | File | Triggers | Artifacts & Releases Generated |
| :--- | :--- | :--- | :--- |
| **Flutter CI** | `.github/workflows/flutter-ci.yml` | Push & PR to `main` | Format check, Static Analysis (`strict-casts`, `strict-inference`), Unit & Widget tests |
| **Flutter Android Build** | `.github/workflows/flutter-android-build.yml` | Push to `main`, Manual dispatch | Builds Debug APK & Split-per-ABI Release APKs, published to GitHub Releases (`v1.0.0-release`) |
| **Backend CI** | `.github/workflows/backend-ci.yml` | Push & PR to `main` | TypeScript compile, 19 Jest test suites (314 tests) on Node.js 22 LTS with MongoDB 7.0 container |

### How to Download Android APK Releases
1. Navigate to the GitHub repository's **Releases** tab.
2. Select the latest release: **TradeVerse Android Release v1.0.0**.
3. Choose the optimal APK for your device architecture:
   - **`app-arm64-v8a-release.apk`**: Modern 64-bit Android smartphones (95%+ of current devices, fastest and smallest download).
   - **`app-armeabi-v7a-release.apk`**: Older 32-bit Android devices.
   - **`app-x86_64-release.apk`**: Android emulators and ChromeOS.
   - **`app-debug.apk`**: Universal debug build with developer logs enabled.
4. Transfer and install the `.apk` directly onto any physical Android device (API 24+).

---

## 3. Hosting on Render (render.com) — Step-by-Step Guide

TradeVerse AI is fully configured for automated cloud deployment to **Render** using the root `render.yaml` Blueprint or as a manual Web Service.

### Option A: Automated Blueprint Deployment (Recommended)

1. Sign in to your [Render Dashboard](https://dashboard.render.com/).
2. Click **New +** → **Blueprint**.
3. Connect and select your GitHub repository: `Abhinavkunnummal/VirtualTradingApp`.
4. Render detects `render.yaml` at the repository root and configures the **`virtualtradingapp`** service:
   - **Runtime**: Node.js
   - **Root Directory**: `apps/api`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `node dist/server.js`
   - **Health Check Path**: `/health`
5. Render prompts you for secrets marked with `sync: false`:
   - `MONGODB_URI`: Your MongoDB Atlas connection string.
   - `ANGEL_ONE_API_KEY`: Angel One SmartAPI key (optional for live broker feeds).
   - `ANGEL_ONE_CLIENT_CODE`: Angel One client code (optional).
   - `ANGEL_ONE_PIN`: Angel One PIN (optional).
   - `ANGEL_ONE_TOTP_SECRET`: Base32 TOTP secret for automated morning login (optional).
   - `FINNHUB_API_KEY`: Finnhub key for live US stock trading (optional).
   - `ALPHA_VANTAGE_API_KEY`: Alpha Vantage key for fallback search/quotes (optional).
6. Click **Apply**. Render automatically generates high-entropy cryptographic keys for `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` and provisions the instance.

---

### Option B: Manual Web Service Setup

If configuring the Web Service manually:

1. In the Render Dashboard, click **New +** → **Web Service**.
2. Select your repository: `Abhinavkunnummal/VirtualTradingApp`.
3. Configure the service settings:
   - **Name**: `virtualtradingapp`
   - **Region**: Nearest region to your users (e.g., `Singapore` or `Oregon`)
   - **Branch**: `main`
   - **Root Directory**: `apps/api`
   - **Runtime**: `Node`
   - **Build Command**: `npm install && npm run build`
   - **Start Command**: `node dist/server.js`
   - **Instance Type**: `Free`
4. Under **Advanced**, set **Health Check Path** to `/health`.
5. Under **Environment Variables**, configure the variables detailed in Section 4.
6. Click **Create Web Service**.

---

## 4. Production Environment Variables Reference

| Variable | Required? | Default / Example Value | Description |
| :--- | :---: | :--- | :--- |
| `NODE_ENV` | **Yes** | `production` | Enables production security, suppresses stack traces, enforces required secrets |
| `PORT` | **Yes** | `10000` | HTTP and WebSocket server listening port (Render standard is 10000) |
| `MONGODB_URI` | **Yes** | `mongodb+srv://<usr>:<pwd>@cluster0.mongodb.net/tradeverse?retryWrites=true&w=majority` | Primary MongoDB Atlas connection string |
| `JWT_ACCESS_SECRET` | **Yes** | 64-char random hex string (`openssl rand -hex 32`) | Secret key used to sign short-lived access tokens (min 32 chars) |
| `JWT_REFRESH_SECRET` | **Yes** | 64-char random hex string (`openssl rand -hex 32`) | Secret key used to sign long-lived refresh session tokens (min 32 chars) |
| `CORS_ORIGINS` | No | `*` or `https://app.tradeverse.ai,http://localhost:3000` | Allowed origins. Supports wildcard `*` or comma-separated domains |
| `STARTING_CAPITAL` | No | `0` | New users start at 0 virtual capital and add funds manually via Add Funds |
| `ANGEL_ONE_API_KEY` | No | Broker API Key | Angel One SmartAPI integration for live tick-by-tick feeds (NSE/BSE/MCX) |
| `ANGEL_ONE_CLIENT_CODE` | No | Broker Client ID | Angel One client account code |
| `ANGEL_ONE_PIN` | No | 4-digit Account PIN | Angel One security PIN |
| `ANGEL_ONE_TOTP_SECRET` | No | Base32 TOTP Secret | Used by backend to dynamically generate 2FA TOTP tokens on morning re-logins |
| `FINNHUB_API_KEY` | No | API Key | Finnhub WebSocket / REST provider for live US stocks |
| `TWELVE_DATA_API_KEY` | No | API Key | Twelve Data provider for international quotes |
| `ALPHA_VANTAGE_API_KEY` | No | API Key | Alpha Vantage provider for fallback quotes and equity search |
| `BINANCE_WS_URL` | No | `wss://stream.binance.com:9443/ws` | Binance WebSocket endpoint for 24/7 crypto spot tickers and klines |

> [!IMPORTANT]
> **Environment Validation & Security**: At startup, `validateEnvironment()` verifies all required production variables. If any required variables are missing, the server prints the missing variable names with clear instructions and halts—**secret values are never printed in logs**.

---

## 5. Free-Tier Sleep Handling & Resilience

Render Free Tier instances spin down after 15 minutes of inactivity. TradeVerse AI incorporates proactive mechanisms to handle sleep/wake cycles gracefully:

1. **Wake-up Catalog Ingestion**:
   - `InstrumentMasterService` runs a freshness check on wake-up.
   - If the database catalog has fewer than 1,000 instruments or if the newest document was updated more than 24 hours ago, a background ingestion job is automatically scheduled.
   - The server serves cached memory data immediately, never blocking incoming user requests.
2. **Wake-up SmartAPI Broker Login**:
   - `AngelOneService.init()` runs on wake-up. If broker credentials exist, it automatically requests a fresh JWT token using TOTP generation and establishes the WebSocket tick feed.
3. **Mobile Client Cold-Start Timeout**:
   - The Flutter mobile application uses a 30-second `connectTimeout` and `receiveTimeout` in Dio to accommodate Render instance spin-ups without failing requests.
   - Automatic exponential backoff reconnection is implemented in `LiveTickerService` for WebSocket stream drops.

---

## 6. Health & Monitoring Endpoints

### `GET /health`
Returns comprehensive system and provider telemetry:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2026-11-05T09:15:00.000Z",
  "uptime": 124.5,
  "environment": "production",
  "database": {
    "status": "connected",
    "name": "tradeverse"
  },
  "providers": {
    "angelOne": "connected",
    "binance": "connected",
    "finnhub": "connected",
    "twelveData": "not configured",
    "alphaVantage": "configured"
  },
  "services": {
    "database": "connected",
    "paperEngine": "active",
    "marketData": "active"
  }
}
```

### `GET /health/liveness`
Simple probe returning HTTP 200 `{ "status": "live", "uptime": 124.5 }`.

### `GET /health/readiness`
Ensures MongoDB connection is established before routing live traffic.

---

## 7. Android Release Signing with GitHub Secrets

To sign release APKs in GitHub Actions without committing keys to the repository:

1. Generate your production release keystore locally:
   ```bash
   keytool -genkey -v -keystore release.keystore -alias tradeverse -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Convert the keystore file to base64:
   ```bash
   # On macOS / Linux:
   base64 -i release.keystore | tr -d '\n' > keystore_base64.txt
   # On Windows PowerShell:
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore")) | Out-File -Encoding ascii keystore_base64.txt
   ```
3. In your GitHub repository:
   - Navigate to **Settings** → **Secrets and variables** → **Actions**.
   - Click **New repository secret** and add:
     - `KEYSTORE_BASE64`: Contents of `keystore_base64.txt`
     - `KEYSTORE_PASSWORD`: Keystore store password
     - `KEY_ALIAS`: Keystore alias (e.g. `tradeverse`)
     - `KEY_PASSWORD`: Key password
4. The GitHub Actions workflow automatically detects these secrets, decodes the keystore into `android/app/release.keystore`, signs the APKs, and uploads them to the GitHub Release. If no secrets are provided, it builds using the default signing configuration so CI never breaks.
