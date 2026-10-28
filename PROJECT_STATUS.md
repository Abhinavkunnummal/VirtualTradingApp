# TradeVerse AI — Project Status & Roadmap

## Master Overview

| Phase | Description | Status | Verification / Blocker |
|---|---|:---:|---|
| **Phase 1** | Repository Inspection, Stitch Discovery, Monorepo Architecture & Cloud Build Workflows | **Completed** | Clean repo scaffolded, Stitch project connected (49 screens cataloged), Workflows configured |
| **Phase 2** | Flutter Mobile App Scaffolding, Stitch Design Tokens, Router & Shell Screens | **In Progress** | Design tokens, GoRouter multi-tab shell, Home Dashboard, Navigation tests |
| **Phase 3** | Node.js Backend, TypeScript Config, MongoDB Models & JWT Authentication | Pending | Planned for Phase 3 |
| **Phase 4** | Virtual Trading Engine, Margin/Leverage Simulation, Holdings & P&L | Pending | Planned for Phase 4 |
| **Phase 5** | Multi-Asset Market Data Bus, Watchlists & Interactive Candlestick Charts | Pending | Planned for Phase 5 |
| **Phase 6** | AI Trading Assistant (Educational Scenarios, Risk Evaluator) & News Feed | Pending | Planned for Phase 6 |
| **Phase 7** | Real-Time Chat Rooms, Socket.IO WebSockets & Price Alerts | Pending | Planned for Phase 7 |
| **Phase 8** | End-to-End Verification, Security Audits, Deployment & APK Cloud Build Verification | Pending | Planned for Phase 8 |

---

## Phase 1 Inspection Findings

1. **Local Environment**:
   - OS: Windows 11
   - Node.js: `v24.20.0` (Installed)
   - npm: `11.19.0` (Installed)
   - Git: `v2.55.0.windows.5` (Installed, user `AbhinavK`)
   - Flutter / Dart: **Not installed locally** (Strict constraint respected)
   - Android Studio / SDK: **Not installed locally** (Strict constraint respected)
2. **Google Stitch Connection**:
   - Connection: Fully operational via MCP Server `stitch`.
   - Connected Project: `projects/6279083996241232485` ("TradeVerse AI Paper Trading Mobile").
   - Device Type: `MOBILE`.
   - Catalog: 49 screens retrieved, analyzed, and mapped.
   - Design System Tokens: Dark mode palette, Inter tabular typography, 4px/8px micro-grid, Material 3 foundation extracted.
3. **GitHub CI/CD Workflows**:
   - Configured `.github/workflows/flutter-ci.yml` (Lint, format, analyze, widget test).
   - Configured `.github/workflows/flutter-android-build.yml` (Java 17, Flutter 3.29.0 pinned, Android debug APK compilation and artifact upload).
   - Configured `.github/workflows/backend-ci.yml` (Node.js LTS, dependencies, typecheck, Jest tests).

---

## Definition of Done (First Usable Release) Checklist

- [ ] Flutter app implemented using approved Stitch design system tokens.
- [ ] 5 primary navigation destinations functional (Home, Markets, Trade, Community, Portfolio).
- [ ] App connects to backend API via configurable `API_BASE_URL`.
- [ ] Virtual sandbox account initialized with configurable starting capital (e.g. ₹10,00,000).
- [ ] Simulated paper-trading orders execute with realistic slippage and margin rules.
- [ ] Portfolio calculations (Holdings, Positions, MTM P&L) compute correctly.
- [ ] App clearly flags simulated vs live/delayed data.
- [ ] Backend tests pass locally and in CI.
- [ ] Flutter analysis and tests pass in GitHub Actions.
- [ ] Downloadable APK generated via GitHub Actions workflow run.
- [ ] Zero local Flutter or Android SDK installation required on host machine.
