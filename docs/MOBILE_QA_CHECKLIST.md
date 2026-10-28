# TradeVerse AI — Mobile QA & Release Verification Checklist

This checklist defines the complete smoke testing and manual quality assurance procedures for TradeVerse AI on physical Android devices and emulator testbeds.

---

## 1. Environment & Build Configuration

| Parameter | Development | Staging / Cloud QA | Production Release |
| :--- | :--- | :--- | :--- |
| **API Base URL** | `http://10.0.2.2:5000/api/v1` (Emulator) or `http://<LAN_IP>:5000/api/v1` | `https://api-staging.tradeverse.ai/api/v1` | `https://api.tradeverse.ai/api/v1` |
| **WebSocket URL**| `http://10.0.2.2:5000` or `http://<LAN_IP>:5000` | `https://api-staging.tradeverse.ai` | `https://api.tradeverse.ai` |
| **Build Command**| `flutter build apk --debug` | `flutter build apk --release --dart-define=API_BASE_URL=https://api-staging.tradeverse.ai/api/v1` | `flutter build appbundle --release --dart-define=API_BASE_URL=https://api.tradeverse.ai/api/v1` |
| **Min SDK** | Android 7.0 (API Level 24) | Android 7.0 (API Level 24) | Android 7.0 (API Level 24) |
| **Target SDK** | Android 14 (API Level 34) | Android 14 (API Level 34) | Android 14 (API Level 34) |

---

## 2. Test Execution Matrix

### Flow 1: Authentication & Demo Sandbox
- [ ] **Launch & Splash**: App launches smoothly without blank screens or flashes.
- [ ] **Unauthenticated Redirection**: App navigates directly to `LoginScreen`.
- [ ] **Email & Password Validation**:
  - Blank inputs display error messages.
  - Invalid email syntax (`user@`, `user.com`) displays `'Enter a valid email address'`.
  - Passwords under 8 characters trigger client-side validation errors.
- [ ] **New Registration**:
  - Register with a unique email and custom virtual starting capital.
  - Verify automatic JWT storage in encrypted shared preferences (`flutter_secure_storage`).
  - Verify redirection to Home Dashboard with personalized display name.
- [ ] **Demo Mode Bypass**:
  - Tap `'Explore in Demo Mode'` on LoginScreen.
  - Verify immediate entry into Sandbox without requiring network or server connection.
  - Confirm yellow `'DEMO MODE'` header badge and `'Explicit Demo Sandbox • Fictional Funds'` disclaimers are present.
- [ ] **Session Expiry & Token Refresh**:
  - When access token expires (15m), verify silent rotation via `POST /auth/refresh`.
  - When refresh token is revoked or replayed, verify forced logout and redirect to LoginScreen with expired session notice.

---

### Flow 2: Market Discovery & Watchlists
- [ ] **Tab Navigation**: Bottom navigation bar switches between Home, Markets, Trade, Community, and Portfolio without state corruption.
- [ ] **Market Tickers**: Quotes display live ticker cards with price, rupee delta, percentage change, and high/low ranges.
- [ ] **Category Chips**: Selecting `All`, `Equities`, `Indices`, `Commodities`, or `Crypto` correctly filters instrument list.
- [ ] **Instrument Search**: Real-time substring filter finds symbols (e.g., searching `'RELI'` shows `RELIANCE`).
- [ ] **Watchlist Toggle**:
  - Tapping star icon adds/removes instrument from user's watchlist.
  - Watchlist view persists state across tab switches and app restarts.
- [ ] **Simulated Price Indicators**: Verify all displayed quotes carry the `'SIMULATED'` badge.

---

### Flow 3: Order Ticket & Execution Engine
- [ ] **Instrument Selection**: Opening Trade tab defaults to selected instrument or allows instant switching via modal sheet.
- [ ] **Interactive Candlestick Chart**:
  - Chart renders green/red candlesticks with high/low wicks.
  - Interval selector toggles timeframe (1m, 5m, 15m, 1h, 1d) and fetches corresponding OHLCV history.
- [ ] **Product Selection**:
  - Toggle between **Delivery (CNC)** and **Intraday (MIS)**.
  - CNC requires 100% upfront virtual cash.
  - MIS displays 5x intraday leverage calculation and mandatory 3:15 PM auto square-off warning.
- [ ] **Order Types**:
  - **MARKET**: Price input disabled; fills at simulated market quote + slippage.
  - **LIMIT**: Price input enabled; requires limit price specification.
  - **SL / SL-M**: Trigger price input displayed; validates trigger semantics (BUY trigger $\ge$ market, SELL trigger $\le$ market).
- [ ] **Fee & Tax Calculation**:
  - Expanding charges modal displays Zerodha-style breakdown (Brokerage: ₹20 / 0.03%, STT/CTT: 0.1%, Exchange turn-over fees, SEBI charges, GST 18%).
- [ ] **Order Placement & Execution**:
  - Place BUY order: verifies sufficient available capital before submission.
  - Displays instant execution confirmation dialog with fill price, slippage, and reference ID.
  - Fills update virtual cash balance and portfolio holdings immediately.
- [ ] **Insufficient Margin Rejection**:
  - Attempting to place an order exceeding available capital displays a clean, informative error snackbar.

---

### Flow 4: Portfolio, Holdings & Ledger Audit
- [ ] **Summary Card**:
  - Total portfolio value, available cash, reserved margin, and total P&L correctly match holdings.
  - Fictional funds notice (`Simulated Capital • No Real Money`) clearly visible.
- [ ] **Holdings List**:
  - Holdings cards display quantity, average buy price, current market price, and unrealized P&L in green/red.
  - Tapping a holding pre-populates the trade order ticket with symbol for quick exit.
- [ ] **Capital Reset**:
  - Tapping reset capital allows resetting balance (e.g. ₹10,00,000).
  - Confirms reset prompt.
  - Verifies all holdings are liquidated and ledger records a `CAPITAL_RESET` transaction.

---

### Flow 5: AI Trading Assistant & News
- [ ] **Pre-configured Prompt Chips**:
  - Tapping chips (`RSI Momentum`, `Options Greeks`, `Risk-to-Reward Ratio`, `Stop Loss Strategy`) auto-populates query.
- [ ] **Educational Concept Explanation**:
  - Explanations render with clear definition, core principles, example scenarios, and risk factors.
  - Generated responses are marked with `'AI-Generated Analysis'` disclaimer.
- [ ] **Trade Risk Estimator**:
  - Requesting trade risk on a proposed setup calculates estimated max loss, margin requirement, and reward-to-risk ratio.
- [ ] **Curated News Summaries**:
  - Feed renders verified financial news summaries with sentiment tags (`BULLISH`, `BEARISH`, `NEUTRAL`), timestamp, and citation source.
- [ ] **Input Bounds & Guardrails**:
  - Text field limits input to 200 characters.
  - Injection attempts (e.g., `IGNORE PREVIOUS INSTRUCTIONS`) are safely handled and rejected by server prompt guardrails.

---

### Flow 6: Community Trading Floor & Discussion
- [ ] **Room Selection**:
  - Switch between discussion floors: `Live Trading Floor`, `NIFTY & Equities Desk`, `Crypto 24/7 Floor`, `MCX Gold & Crude Hub`.
- [ ] **Message Stream**:
  - Messages display author name, timestamp, message body, trade tag badge, and sentiment pill.
- [ ] **Share Paper Idea**:
  - Compose sheet allows posting setup with optional instrument tag and sentiment.
  - New message broadcasts to room via WebSocket in real time.
- [ ] **Channel Isolation**:
  - Private events (order fills, execution notices) are never broadcast to community rooms; they stream exclusively to authenticated user channel `user:<userId>`.

---

### Flow 7: Network Resilience & Error Recovery
- [ ] **Airplane Mode / Network Drop**:
  - Enabling Airplane mode displays non-intrusive offline indicator.
  - Existing cached screens remain readable without crashing.
- [ ] **Reconnection**:
  - Restoring connectivity automatically reconnects Socket.IO market stream.
- [ ] **Server Error Redaction**:
  - In production mode, server errors return clean messages without raw database errors, stack traces, or internal server paths.
