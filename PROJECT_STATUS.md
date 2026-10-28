# TradeVerse AI — Project Status & Roadmap

## Master Overview

| Phase | Description | Status | Verification / Blocker |
|---|---|:---:|---|
| **Phase 1** | Repository Inspection, Stitch Discovery, Monorepo Architecture & Cloud Build Workflows | **Completed** | Clean repo initialized, Stitch project connected (49 screens cataloged), Workflows configured |
| **Phase 2** | Flutter Mobile App Scaffolding, Stitch Design Tokens, Router & Shell Screens | **Completed** | Stitch tokens, GoRouter multi-tab shell, Dio API Client, Riverpod State Providers, Login/Register screens, Demo Mode, and Widget Tests |
| **Phase 3** | Node.js Backend, TypeScript Config, MongoDB Models & JWT Authentication | **Completed** | Validated config, 8 Mongoose models, Argon2id/Bcrypt + JWT refresh rotation, Paper Account, Portfolio & Watchlist endpoints, 16/16 backend tests passed |
| **Phase 4** | Virtual Trading Engine, Margin/Leverage Simulation, Holdings & P&L | Pending | Planned for Phase 4 |
| **Phase 5** | Multi-Asset Market Data Bus, Watchlists & Interactive Candlestick Charts | Pending | Planned for Phase 5 |
| **Phase 6** | AI Trading Assistant (Educational Scenarios, Risk Evaluator) & News Feed | Pending | Planned for Phase 6 |
| **Phase 7** | Real-Time Chat Rooms, Socket.IO WebSockets & Price Alerts | Pending | Planned for Phase 7 |
| **Phase 8** | End-to-End Verification, Security Audits, Deployment & APK Cloud Build Verification | Pending | Planned for Phase 8 |

---

## Phase 2 & 3 Completed Features

### Backend (Node.js + Express + TypeScript + MongoDB Atlas)
1. **Configuration**:
   - Environment schema validation via Zod (`PORT`, `NODE_ENV`, `MONGODB_URI`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `CORS_ORIGINS`, `STARTING_CAPITAL`).
   - Length checks: JWT secrets must be $\ge 32$ characters in production.
2. **MongoDB Mongoose Models**:
   - `User`: Unique normalized email, bcrypt password hash, display name, experience level, preferred markets, status.
   - `RefreshSession`: Secure SHA-256 token hash, TTL auto-expiration, revocation tracking, IP/UserAgent metadata.
   - `PaperAccount`: Unique 1-to-1 account link, starting capital (default ₹10 Lakhs), available cash, reserved margin, simulated flag.
   - `Watchlist`: Unique compound index (user + name), instruments list, default watchlist flag.
   - `Instrument`: Multi-asset master records across NSE, BSE, MCX, US, and Crypto.
   - `Order`: Paper order lifecycle (Market, Limit, SL, SL-M, CNC/MIS, quantity, prices, idempotency key).
   - `Execution`: Trade fills, simulated fees, slippage, price source, timestamp.
   - `Holding`: Delivery positions, average buy cost, reserved margin, compound uniqueness on (account, instrument).
3. **Authentication & Session Lifecycle**:
   - `POST /api/v1/auth/register`: Validates input, hashes password with 12 salt rounds, creates user, idempotently initializes ₹10 Lakh paper account and default watchlist, returns short-lived access token + rotated refresh token.
   - `POST /api/v1/auth/login`: Timing-safe authentication, creates fresh refresh session.
   - `POST /api/v1/auth/refresh`: Rotates refresh token, invalidates old token, returns new access token.
   - `POST /api/v1/auth/logout`: Revokes active refresh session.
   - `GET /api/v1/auth/me`: Protected profile endpoint.
4. **Paper Account & Portfolio APIs**:
   - `GET /api/v1/paper-account`: Returns current virtual balance & simulation disclaimer.
   - `POST /api/v1/paper-account/reset`: Resets sandbox funds to ₹5L, ₹10L, ₹25L, or ₹50L.
   - `GET /api/v1/portfolio`: Computes live market value, unrealized P&L, holdings array.
   - `GET /api/v1/watchlists`, `POST /api/v1/watchlists`, `DELETE /api/v1/watchlists/:id`: Full watchlist CRUD with ownership enforcement.
5. **Backend Verification**:
   - **16/16 Jest integration tests PASSED** locally against MongoDB service (`tests/auth.test.ts`, `tests/paperAccount.test.ts`, `tests/health.test.ts`).
   - TypeScript build (`npm run build`) compiles cleanly without errors.

### Mobile Frontend (Flutter + Riverpod + GoRouter + Dio)
1. **Network Layer**:
   - `ApiClient` with Dio, environment-configured `API_BASE_URL` (`String.fromEnvironment`), request timeouts, and interceptors.
   - `TokenStorage` with `FlutterSecureStorage` (encrypted SharedPreferences on Android).
   - Automatic 401 token refresh queue with session expiration triggers.
   - Custom `ApiException` translating network timeouts, 401 unauthenticated, 404, and 409 conflict errors.
2. **State Management (Riverpod)**:
   - `authProvider`: Reactive authentication state (initial, unauthenticated, authenticated, loading, demoMode).
   - `portfolioProvider`: Active sandbox balances, holdings, and capital reset mutations.
   - `marketOverviewProvider`: Multi-asset ticker feeds with explicitly labelled simulated prices.
   - `watchlistsProvider`: User-customized watchlists.
3. **User Interface & Navigation**:
   - Complete 5-destination bottom navigation shell: Home, Markets, Trade, Community, Portfolio.
   - `LoginScreen` & `RegisterScreen` with form validation, password visibility toggles, and clear error banners.
   - Protected route redirection in GoRouter.
   - `DemoModeBanner`: Explicit badge and disclaimer when operating in fictional demo mode.
   - `LoadingStateWidget` & `ErrorStateWidget` with retry callbacks for resilient UX.
4. **Widget & Unit Tests**:
   - `test/widget_test.dart`: Verifies 5-tab navigation, shell switching, and dashboard telemetry.
   - `test/auth_flow_test.dart`: Verifies unauthenticated redirection, form validation, and demo mode access.
   - `test/api_error_handling_test.dart`: Verifies Dio error mapping to domain exceptions.

---

## Definition of Done (First Usable Release) Progress

- [x] Flutter app implemented using approved Stitch design system tokens.
- [x] 5 primary navigation destinations functional (Home, Markets, Trade, Community, Portfolio).
- [x] App connects to backend API via configurable `API_BASE_URL` and `Dio`.
- [x] JWT authentication, refresh rotation, and logout working end-to-end.
- [x] Virtual sandbox account initialized with configurable starting capital (e.g. ₹10,00,000).
- [x] Portfolio calculations (Holdings, Positions, MTM P&L) compute correctly.
- [x] App clearly identifies simulated vs demo data.
- [x] 16/16 backend tests pass locally.
- [x] Cloud CI workflows configured for Flutter, Android APK build, and Backend CI.
- [ ] Connect remote Git repository to trigger cloud GitHub Actions build.
- [ ] Download verified APK artifact from GitHub Actions run.
