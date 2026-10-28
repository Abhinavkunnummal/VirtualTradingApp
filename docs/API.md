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
- **Response `200 OK`**:
```json
{
  "success": true,
  "message": "Session refreshed successfully.",
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "88ef12..."
}
```

### `POST /api/v1/auth/logout`
Revokes the refresh session.
- **Request Body**:
```json
{
  "refreshToken": "88ef12..."
}
```

### `GET /api/v1/auth/me`
Requires `Authorization: Bearer <accessToken>`.
Returns authenticated profile and active paper account ID.

---

## 3. Paper Accounts & Capital (`/api/v1/paper-account`)

### `GET /api/v1/paper-account`
Requires authentication. Returns current virtual balance, cash available, and simulated disclaimer.
- **Response `200 OK`**:
```json
{
  "success": true,
  "account": {
    "id": "671fb0a456...",
    "accountName": "Sandbox v2.4 (Default)",
    "baseCurrency": "INR",
    "startingCapital": 1000000.00,
    "availableCash": 425000.00,
    "reservedMargin": 0.00,
    "isSimulated": true,
    "disclaimer": "Fictional capital for paper trading simulation only. No real funds.",
    "status": "ACTIVE"
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

## 4. Portfolio & Orders (`/api/v1/portfolio`)

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

### `GET /api/v1/portfolio/orders`
Retrieves user's simulated orders with optional `?status=PENDING|FILLED|CANCELLED|REJECTED` filter.

---

## 5. Watchlists (`/api/v1/watchlists`)

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

### `POST /api/v1/watchlists/:id/symbols`
Adds a ticker symbol to a watchlist.
