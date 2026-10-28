# TradeVerse AI — API Specifications

## Base URL
- Development / Local API: `http://localhost:5000/api/v1`
- Production API: Configured via `API_BASE_URL` environment variable

## Authentication
Authentication uses standard Bearer JWT tokens in the `Authorization` header:
```
Authorization: Bearer <jwt_access_token>
```

---

## 1. System & Health

### `GET /health`
Returns system health, database status, and uptime.
- **Response `200 OK`**:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2026-10-28T13:20:00.000Z",
  "database": "connected",
  "services": {
    "marketData": "active",
    "paperEngine": "active"
  }
}
```

---

## 2. Authentication & Users (`/api/v1/auth`, `/api/v1/users`)

### `POST /api/v1/auth/register`
Creates a new trader account and automatically initializes a virtual sandbox account.
- **Request Body**:
```json
{
  "email": "trader@example.com",
  "password": "StrongPassword123!",
  "name": "Arjun Sharma",
  "initialVirtualCapital": 1000000
}
```
- **Response `201 Created`**:
```json
{
  "success": true,
  "token": "eyJhbGciOi...",
  "user": {
    "id": "usr_671fb0a",
    "email": "trader@example.com",
    "name": "Arjun Sharma",
    "virtualAccountId": "acc_9921fa"
  }
}
```

### `POST /api/v1/auth/login`
Authenticates a user and returns a JWT token.

### `GET /api/v1/users/profile`
Retrieves authenticated user profile, tier, trading stats, and settings.

---

## 3. Paper Accounts & Capital (`/api/v1/paper-accounts`)

### `GET /api/v1/paper-accounts/current`
Returns active virtual account balance, cash available, invested capital, and overall P&L.
- **Response `200 OK`**:
```json
{
  "id": "acc_9921fa",
  "accountName": "Sandbox v2.4 (Default)",
  "currency": "INR",
  "startingCapital": 1000000.00,
  "cashBalance": 425000.00,
  "investedExposure": 823750.00,
  "totalPortfolioValue": 1248750.00,
  "totalPnl": 48750.00,
  "totalPnlPercent": 4.06,
  "todaysPnl": 48750.00,
  "todaysPnlPercent": 4.06,
  "isSimulated": true
}
```

### `POST /api/v1/paper-accounts/reset-capital`
Resets virtual sandbox funds back to a user-defined balance (e.g. ₹5,00,000 or ₹10,00,000).

---

## 4. Market Data & Watchlists (`/api/v1/market-data`, `/api/v1/watchlists`)

### `GET /api/v1/market-data/tickers`
Returns market indices and active ticker quotes across NSE, BSE, MCX, US, and Crypto.
- **Query Params**: `category=NSE|BSE|MCX|US|CRYPTO`
- **Response `200 OK`**:
```json
[
  {
    "symbol": "NIFTY 50",
    "exchange": "NSE",
    "price": 24852.15,
    "change": 178.40,
    "changePercent": 0.72,
    "high": 24920.00,
    "low": 24780.10,
    "currency": "INR",
    "status": "SIMULATED",
    "updatedAt": "2026-10-28T13:20:00.000Z"
  },
  {
    "symbol": "RELIANCE",
    "exchange": "NSE",
    "price": 2945.50,
    "change": 18.40,
    "changePercent": 0.63,
    "currency": "INR",
    "status": "SIMULATED",
    "updatedAt": "2026-10-28T13:20:00.000Z"
  }
]
```

### `GET /api/v1/market-data/quote/:symbol`
Retrieves detailed quote, L2/L3 order book depth, OHLC, 52-week high/low, and volume.

### `GET /api/v1/market-data/candles/:symbol`
Retrieves candlestick history for charting (`interval=1m|5m|15m|1h|1d`, `limit=100`).

### `GET /api/v1/watchlists`
Lists user watchlists and pinned instruments.

---

## 5. Orders & Execution Simulation (`/api/v1/orders`)

### `POST /api/v1/orders`
Submits a simulated paper-trading order with server-side margin verification.
- **Request Body**:
```json
{
  "symbol": "RELIANCE",
  "exchange": "NSE",
  "side": "BUY",
  "orderType": "MARKET",
  "product": "CNC",
  "quantity": 10,
  "price": 2945.50,
  "triggerPrice": null,
  "idempotencyKey": "uuid-v4-idem-key"
}
```
- **Response `201 Created`**:
```json
{
  "orderId": "ord_8820f12",
  "status": "FILLED",
  "symbol": "RELIANCE",
  "side": "BUY",
  "product": "CNC",
  "quantity": 10,
  "filledQuantity": 10,
  "averagePrice": 2945.55,
  "slippage": 0.05,
  "brokerage": 20.00,
  "taxesAndCharges": 6.85,
  "totalCost": 29482.35,
  "createdAt": "2026-10-28T13:20:05.000Z",
  "message": "Simulated order filled successfully at ₹2,945.55"
}
```

### `GET /api/v1/orders`
Retrieves active and historical orders with status filters (`status=OPEN|FILLED|CANCELLED|REJECTED`).

### `DELETE /api/v1/orders/:orderId`
Cancels a pending limit or stop-loss order.

---

## 6. Portfolio, Holdings & Positions (`/api/v1/portfolio`)

### `GET /api/v1/portfolio/holdings`
Returns active Delivery (CNC) equity holdings, average buy price, current value, and unrealized P&L.

### `GET /api/v1/portfolio/positions`
Returns active Intraday (MIS) leveraged positions with MTM calculations.

### `GET /api/v1/portfolio/analytics`
Returns P&L attribution, sector diversification, win-rate, profit factor, and tax estimates.

---

## 7. AI Trading Assistant (`/api/v1/ai-assistant`)

### `POST /api/v1/ai-assistant/analyze`
Generates educational technical scenarios and risk evaluation for a symbol based on verified server-side market data.
- **Request Body**:
```json
{
  "symbol": "RELIANCE",
  "prompt": "Evaluate support and resistance on the 1-hour timeframe with current RSI."
}
```
- **Response `200 OK`**:
```json
{
  "symbol": "RELIANCE",
  "currentPrice": 2945.50,
  "analysis": "RELIANCE is trading above its 20-period EMA (2,932.00) with RSI at 58.4.",
  "bullishScenario": {
    "entry": 2945.50,
    "target": 2980.00,
    "stopLoss": 2928.00,
    "riskRewardRatio": "1 : 2.0"
  },
  "bearishScenario": {
    "invalidation": 2920.00,
    "warning": "Breakdown below 2,920 opens support retest at 2,890."
  },
  "disclaimer": "Simulated educational scenario. Not financial advice."
}
```

---

## 8. Community, Chat & News (`/api/v1/community`, `/api/v1/chat`, `/api/v1/news`)

- `GET /api/v1/community/feed`: Paginated community posts with verified paper trade badges.
- `POST /api/v1/community/posts`: Create post or share simulated order outcome.
- `GET /api/v1/chat/rooms`: Active trader discussion channels (e.g. `nifty-options`, `crypto-desk`).
- `GET /api/v1/news/feed`: Institutional flash news with market sentiment classification (BULLISH / BEARISH / NEUTRAL).

---

## 9. Real-Time WebSockets (Socket.IO)

- Event `join_ticker` `{"symbols": ["NIFTY 50", "RELIANCE", "BTC/USD"]}`
- Event `ticker_update`: Live price ticks emitted every 500ms - 1000ms.
- Event `order_update`: Real-time order fill / trigger notifications for active user.
- Event `chat_message`: Authenticated message broadcasts in active room.
