# TradeVerse AI — API Specifications

## Base URL
- Development / Local API: `http://localhost:5000/api/v1`
- Android Emulator Loopback: `http://10.0.2.2:5000/api/v1`
- Production API: Configured via `API_BASE_URL` environment variable

## Authentication
Authentication uses standard Bearer JWT tokens in the `Authorization` header:
```
Authorization: Bearer <jwt_access_token>
```
Access tokens expire after 15 minutes. Refresh tokens expire after 7 days and rotate upon every refresh call.

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
  "environment": "development",
  "services": {
    "database": "configured",
    "paperEngine": "active",
    "marketData": "active"
  }
}
```

---

## 2. Authentication & Users (`/api/v1/auth`)

### `POST /api/v1/auth/register`
Creates a user account, initializes a virtual sandbox account with starting capital (default ₹10 Lakhs), creates a default watchlist, and returns access and refresh tokens.
- **Request Body**:
```json
{
  "email": "trader@example.com",
  "password": "StrongPassword123!",
  "displayName": "Arjun Sharma",
  "startingCapital": 1000000
}
```
- **Response `201 Created`**:
```json
{
  "success": true,
  "message": "Registration successful. Virtual paper-trading account initialized.",
  "user": {
    "id": "671fb0a123...",
    "email": "trader@example.com",
    "displayName": "Arjun Sharma",
    "experienceLevel": "BEGINNER",
    "paperAccountId": "671fb0a456...",
    "createdAt": "2026-10-28T13:20:00.000Z"
  },
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "4a18b76e..."
}
```

### `POST /api/v1/auth/login`
Authenticates a user and creates a new refresh session.
- **Request Body**:
```json
{
  "email": "trader@example.com",
  "password": "StrongPassword123!"
}
```
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "Login successful.",
  "user": {
    "id": "671fb0a123...",
    "email": "trader@example.com",
    "displayName": "Arjun Sharma",
    "paperAccountId": "671fb0a456..."
  },
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "9d81f2..."
}
```

### `POST /api/v1/auth/refresh`
Rotates the refresh token and returns a fresh access token. Invalidates the previous session.
- **Request Body**:
```json
{
  "refreshToken": "4a18b76e..."
}
```

### `POST /api/v1/auth/logout`
Revokes the refresh token and invalidates the session.
- **Request Body**:
```json
{
  "refreshToken": "4a18b76e..."
}
```

### `GET /api/v1/auth/me`
Requires authentication. Returns current user profile and linked virtual paper account.

---

## 3. Paper Trading Accounts (`/api/v1/paper-account`)

### `GET /api/v1/paper-account`
Requires authentication. Retrieves user's sandbox balance, available cash, and reserved margin.
- **Response `200 OK`**:
```json
{
  "success": true,
  "account": {
    "id": "671fb0a456...",
    "userId": "671fb0a123...",
    "availableCash": 1000000.00,
    "reservedMargin": 0.00,
    "startingCapital": 1000000.00,
    "currency": "INR",
    "isSimulated": true,
    "disclaimer": "This account uses virtual paper funds. No real money is at risk."
  }
}
```

### `POST /api/v1/paper-account/reset`
Requires authentication. Resets sandbox funds back to user-chosen capital (₹5L, ₹10L, ₹25L, or ₹50L) and optionally clears open holdings for a fresh start.
- **Request Body**:
```json
{
  "startingCapital": 2500000,
  "resetPortfolio": true
}
```

---

## 4. Virtual Trading Engine (`/api/v1/orders`)

Server-authoritative simulated order execution with Zerodha-style fee and tax structures, realistic slippage, leverage, and margin reservation.

### `POST /api/v1/orders`
Places a paper-trading order.
- **Request Body**:
```json
{
  "symbol": "RELIANCE",
  "exchange": "NSE",
  "side": "BUY",
  "orderType": "MARKET",
  "product": "CNC",
  "quantity": 10,
  "limitPrice": 2945.50,
  "triggerPrice": null,
  "idempotencyKey": "req_1730123456_RELIANCE"
}
```
- **Order Types**: `MARKET`, `LIMIT`, `SL`, `SL_M`
- **Products**:
  - `CNC` (Delivery): 1x margin required, added to delivery holdings.
  - `MIS` (Intraday): 5x leverage ($20\%$ initial margin requirement), tracked as intraday position.
- **Response `201 Created`**:
```json
{
  "success": true,
  "message": "Order executed and filled successfully.",
  "order": {
    "id": "671fb34098...",
    "symbol": "RELIANCE",
    "exchange": "NSE",
    "side": "BUY",
    "orderType": "MARKET",
    "product": "CNC",
    "quantity": 10,
    "status": "FILLED",
    "filledQuantity": 10,
    "averagePrice": 2946.97,
    "isSimulated": true
  },
  "execution": {
    "executionPrice": 2946.97,
    "slippage": 1.47,
    "fees": 49.47,
    "feeBreakdown": {
      "brokerage": 20.00,
      "stt": 29.47,
      "exchangeFee": 0.96,
      "gst": 3.77
    },
    "isSimulated": true
  }
}
```

### `GET /api/v1/orders`
Retrieves user's order history with optional `?status=` and `?symbol=` filtering.

### `GET /api/v1/orders/:id`
Retrieves a single order by ID with its execution history.

### `POST /api/v1/orders/:id/cancel`
Cancels an open order if status is `PENDING` or `PARTIALLY_FILLED`. Releases reserved margin back to available cash.

### `GET /api/v1/orders/executions/history`
Returns detailed trade execution records with fill prices, slippage, and fee breakdowns.

### `GET /api/v1/orders/account/ledger`
Returns complete double-entry auditable ledger entries for balance tracking, deposits, order executions, cancellations, and fees.

---

## 5. Multi-Asset Market Data Bus (`/api/v1/market-data`)

Provider-independent market data architecture covering Indian equities, MCX commodities, US stocks, and 24/7 crypto. All prices carry explicit simulation flags.

### `GET /api/v1/market-data/instruments`
Returns the master list of all supported tradeable instruments.

### `GET /api/v1/market-data/quotes`
Returns latest real-time simulated quotes, percentage changes, day high/low, and volume across all instruments.
- **Response `200 OK`**:
```json
{
  "success": true,
  "count": 10,
  "quotes": [
    {
      "symbol": "RELIANCE",
      "name": "Reliance Industries Ltd.",
      "exchange": "NSE",
      "category": "EQUITY",
      "price": 2945.50,
      "change": 18.40,
      "changePercent": 0.63,
      "high": 2962.00,
      "low": 2928.00,
      "volume": 3450200,
      "status": "SIMULATED",
      "timestamp": "2026-10-28T14:00:00.000Z"
    }
  ]
}
```

### `GET /api/v1/market-data/quote/:symbol`
Returns quote for a specific ticker symbol (e.g. `RELIANCE`, `BTC/USDT`, `NVDA`).

### `GET /api/v1/market-data/candles/:symbol?interval=15m&limit=45`
Generates deterministic OHLCV candlestick series for charting.
- **Supported intervals**: `1m`, `5m`, `15m`, `1h`, `1d`, `1w`
- **Response `200 OK`**:
```json
{
  "success": true,
  "symbol": "RELIANCE",
  "interval": "15m",
  "candles": [
    {
      "timestamp": 1730121600,
      "open": 2938.00,
      "high": 2949.50,
      "low": 2935.20,
      "close": 2945.50,
      "volume": 24500
    }
  ]
}
```

### `GET /api/v1/market-data/status`
Returns market session statuses for NSE, BSE, MCX, US markets, and 24/7 Crypto.

---

## 6. Portfolio & Holdings (`/api/v1/portfolio`)

### `GET /api/v1/portfolio`
Requires authentication. Computes live valuation of virtual holdings, unrealized P&L, and returns overall account status.
- **Response `200 OK`**:
```json
{
  "success": true,
  "portfolio": {
    "totalPortfolioValue": 1248750.00,
    "availableCash": 425000.00,
    "investedValue": 823750.00,
    "startingCapital": 1000000.00,
    "totalPnl": 48750.00,
    "totalPnlPercent": 4.06,
    "isSimulated": true,
    "holdings": [
      {
        "id": "671fc...",
        "symbol": "RELIANCE",
        "exchange": "NSE",
        "quantity": 150,
        "averageBuyPrice": 2880.00,
        "ltp": 2945.50,
        "investedValue": 432000.00,
        "currentValue": 441825.00,
        "unrealizedPnl": 9825.00,
        "unrealizedPnlPercent": 2.27
      }
    ]
  }
}
```

---

## 7. Watchlists (`/api/v1/watchlists`)

### `GET /api/v1/watchlists`
Retrieves user's watchlists and custom lists.

### `POST /api/v1/watchlists`
Creates a new custom watchlist.
- **Request Body**:
```json
{
  "name": "High Beta Movers",
  "instruments": ["RELIANCE", "BTC/USDT", "NVDA"]
}
```

### `DELETE /api/v1/watchlists/:id`
Deletes a custom watchlist (enforces ownership; default watchlist cannot be deleted).
