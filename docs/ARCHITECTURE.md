# TradeVerse AI — System Architecture

## 1. Overview & High-Level Topology

TradeVerse AI is a simulated multi-asset paper-trading platform designed for high-frequency market simulation, educational risk management, algorithmic strategy backtesting, and AI-assisted market analysis.

```
+-------------------------------------------------------------------------------+
|                       Flutter Mobile Client (iOS / Android)                   |
|  - Material 3 Dark UI (Inter Typography + Tabular Figures)                    |
|  - Riverpod State Management + GoRouter Multi-Tab Shell                       |
|  - Dio REST API Client + Socket.IO Real-Time Feed                             |
|  - Local Secure Storage (Auth Tokens & Preferences)                           |
+-------------------------------------------------------------------------------+
                                      |
                     HTTPS (REST /api/v1) & WSS (Socket.IO)
                                      |
+-------------------------------------------------------------------------------+
|                          Node.js / Express API Gateway                         |
|  - Helmet, Rate Limiter, CORS, Request Validation (Zod)                       |
|  - JWT Authentication & RBAC Middleware                                       |
|  - Centralized Error Handling & Structured Logging                            |
+-------------------------------------------------------------------------------+
       |                     |                     |                    |
+--------------+     +---------------+     +---------------+    +---------------+
| Paper-Trading|     | Market Data   |     | AI Assistant  |    | Community &   |
| Engine       |     | Provider Bus  |     | Engine        |    | Chat Engine   |
| - Limit/SL/Mkt|    | - NSE/BSE Feed|     | - Scenarios   |    | - Rooms/Feeds |
| - Slippage/Fee|    | - MCX/Commod. |     | - Explanations|    | - Socket.IO   |
| - Margin Check|    | - Crypto/US   |     | - Risk Audit  |    | - Moderation  |
+--------------+     +---------------+     +---------------+    +---------------+
       |                     |                     |                    |
+-------------------------------------------------------------------------------+
|                        MongoDB Atlas Persistence Layer                        |
|  - Users, VirtualAccounts, Orders, Executions, Holdings, Posts, Messages      |
|  - ACID Multi-Document Transactions for Order Settlement                      |
+-------------------------------------------------------------------------------+
```

---

## 2. Monorepo Repository Structure

```
tradeverse-ai/
  apps/
    mobile/                          # Flutter Native Mobile Application
      lib/
        core/                        # Design tokens, theme, networking, router
          theme/                     # Stitch colors, typography, elevations
          router/                    # GoRouter navigation & shell routes
          network/                   # Dio client, interceptors, error mapping
          constants/                 # App constants, route paths
        features/                    # Feature modules (Clean Architecture)
          auth/                      # Login, registration, onboarding
          home/                      # Home dashboard, ticker carousel, quick actions
          markets/                   # Watchlists, asset search, options chain, crypto
          trade/                     # Order ticket, execution, charts, order flow
          community/                 # Feed, discussion rooms, leaderboard
          portfolio/                 # Balances, holdings, positions, P&L attribution
          ai_assistant/              # Copilot chat, scenario analysis, risk audit
          news/                      # Institutional flash news, sentiment
        shared/                      # Reusable widgets (cards, badges, steppers, buttons)
      test/                          # Flutter unit & widget tests
      android/                       # Android wrapper & Gradle config
      pubspec.yaml                   # Flutter dependencies
      analysis_options.yaml          # Strict linter rules
    api/                             # Node.js / Express TypeScript Backend
      src/
        config/                      # Environment variables & runtime validation
        middleware/                  # Auth, rate-limit, validation, errors
        modules/
          auth/                      # User authentication, JWT tokens
          users/                     # User profile, settings, verification
          market-data/               # Multi-asset ticker feeds & snapshots
          watchlists/                # User watchlists & price alerts
          paper-accounts/            # Virtual accounts & sandbox balances
          orders/                    # Paper order lifecycle & execution engine
          portfolio/                 # Holdings, positions, realised/unrealised P&L
          ai-assistant/              # Educational AI scenarios & risk evaluation
          news/                      # News aggregator & sentiment tagging
          community/                 # Social posts, reactions, comments
          chat/                      # Real-time discussion rooms & Socket.IO
          notifications/             # Push & in-app alerts
        app.ts                       # Express application configuration
        server.ts                    # HTTP & Socket.IO server bootstrap
      tests/                         # Jest/Supertest backend tests
      package.json                   # Backend dependencies & scripts
      tsconfig.json                  # TypeScript compiler configuration
      .env.example                   # Environment configuration template
  packages/
    shared/
      api-contracts/                 # Shared TypeScript models, enums & Zod schemas
  .github/
    workflows/
      flutter-ci.yml                 # Cloud Flutter format, analyze & test
      flutter-android-build.yml      # Cloud Android APK & AAB build & artifact upload
      backend-ci.yml                 # Node.js backend build, lint & test
  docs/
    ARCHITECTURE.md                  # System design & architecture (this file)
    API.md                           # REST API & WebSocket specifications
    DEPLOYMENT.md                    # Cloud deployment & secrets setup
    STITCH_INTEGRATION.md            # Google Stitch design system & screen catalog
  README.md                          # Repository overview & quick start
  PROJECT_STATUS.md                  # Phase tracking & milestone status
  .gitignore                         # Git exclusion rules
```

---

## 3. Paper-Trading Simulation Engine

The simulation engine guarantees financial integrity by executing orders authoritatively on the backend using timestamped market price snapshots.

### Execution Lifecycle

1. **Validation**: Client submits order (`symbol`, `orderType`: MARKET/LIMIT/SL/SL-M, `side`: BUY/SELL, `product`: CNC/MIS, `quantity`, `price`).
2. **Snapshot**: Authoritative backend price service fetches current Ask/Bid quote.
3. **Margin & Balance Calculation**:
   - For Delivery (CNC): `Required = Quantity * ExecutionPrice + Fees`
   - For Intraday (MIS): `Required = (Quantity * ExecutionPrice) / 5 + Fees` (5x leverage)
4. **Slippage & Simulated Friction**:
   - Configurable slippage model based on instrument liquidity (0.01% - 0.05%).
   - Simulated brokerage: ₹20 per executed order (or 0.03%, whichever is lower) + simulated STT, GST, and exchange transaction fees.
5. **Matching & Execution**:
   - `MARKET`: Instant fill at current Ask (for BUY) or Bid (for SELL) +/- slippage.
   - `LIMIT`: Placed into pending state; filled when market quote satisfies limit price.
   - `STOP_LOSS`: Triggered when market crosses trigger price.
6. **Persistence & Ledger**:
   - Updates `VirtualAccount` cash balance.
   - Updates `Holding` (for CNC) or `Position` (for MIS).
   - Records `ExecutionLog` with timestamp, execution price, and fees.
   - Emits real-time event over Socket.IO to connected client.

---

## 4. Market Data Engine

The market data architecture uses a provider-agnostic adapter pattern:

```
[ Market Data Bus ]
        ▲
        ├── NSE/BSE Adapter (Indian Equities & Indices)
        ├── MCX Adapter (Gold, Silver, Crude Oil Commodities)
        ├── US Equities Adapter (S&P 500, NASDAQ, Mega-caps)
        ├── Crypto Adapter (BTC, ETH, SOL 24/7 Orderbook)
        └── Fallback High-Fidelity Simulator (Generates realistic ticks when live feeds are unavailable)
```

Each price packet includes:
- `symbol`: Instrument identifier (e.g. `NSE:RELIANCE`, `MCX:GOLD`, `BINANCE:BTCUSDT`)
- `price`: Latest traded price (LTP)
- `change`: Absolute point change
- `changePercent`: Percentage change
- `high`, `low`, `open`, `close`, `volume`
- `status`: Explicit flag: `LIVE`, `DELAYED`, or `SIMULATED`
- `timestamp`: ISO-8601 server timestamp

---

## 5. AI Market Assistant

The AI Assistant is designed exclusively for educational analysis and risk scenario simulation:
- **Strict Guardrail**: AI does NOT have access to trading execution keys and cannot place orders autonomously.
- **Context Injection**: Prompts are provided with authoritative, sanitized market snapshots (OHLCV, indicators, P&L).
- **Outputs**:
  - Technical indicator explanations (RSI divergence, MACD crossovers, Support/Resistance).
  - Dual scenarios (Bullish hypothesis with target & Bearish invalidation level).
  - Risk/reward ratio calculation.
  - Portfolio concentration analysis (flagging excessive single-stock or sector exposure).

---

## 6. GitHub Actions Cloud CI/CD Architecture

In compliance with the project's strict local constraints:
- **Zero Local Flutter**: The developer machine requires NO Flutter SDK, Dart SDK, Android Studio, or Android emulator.
- **Cloud Runner Pipeline**:
  - `flutter-ci.yml`: Runs on ubuntu-latest, installs pinned Flutter SDK (3.29.0), executes `dart format`, `flutter analyze`, and `flutter test`.
  - `flutter-android-build.yml`: Runs on ubuntu-latest, sets up Java 17, installs Flutter, executes tests, and builds `app-debug.apk` with artifacts uploaded to GitHub Actions for instant download.
  - `backend-ci.yml`: Runs on ubuntu-latest, sets up Node.js 22 LTS, installs dependencies, checks TypeScript types, and executes Jest backend test suites.
