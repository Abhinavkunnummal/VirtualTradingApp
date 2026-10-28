# TradeVerse AI — Autonomous Paper Trading Platform

TradeVerse AI is a next-generation paper-trading and market simulation platform designed for high-density financial ergonomics, simulated institutional order routing, multi-asset markets (NSE/BSE, MCX commodities, US equities, and 24/7 crypto), and educational AI copilot scenarios.

---

## Key Highlights

- **Visual Fidelity**: Fully implemented from the Google Stitch design system (`projects/6279083996241232485`), featuring institutional dark ergonomics, tabular figures, and 49 screen states.
- **Frontend Architecture**: Flutter (Material 3, Riverpod, GoRouter, Dio, Socket.IO client, Flutter Secure Storage).
- **Backend Architecture**: Node.js, Express, TypeScript, MongoDB Atlas, Mongoose, Socket.IO real-time engine, Zod validation.
- **Paper-Trading Simulation Engine**: Deterministic simulated execution supporting Market, Limit, SL, and SL-M orders, leverage/margin simulation (Intraday MIS 5x, Delivery CNC), fees, taxes, and slippage calculations.
- **Zero-Local-Flutter Cloud Builds**: Built entirely via GitHub Actions on cloud runners. Generates downloadable Android APKs without requiring Flutter or Android Studio on your local laptop.

---

## Monorepo Architecture

```
tradeverse-ai/
├── apps/
│   ├── mobile/             # Flutter Mobile Application
│   └── api/                # Node.js + Express + TypeScript Backend
├── packages/
│   └── shared/             # Shared TypeScript API Contracts & Schemas
├── .github/
│   └── workflows/          # GitHub Actions CI/CD (Flutter CI, Android APK, Backend CI)
├── docs/                   # Architecture, Stitch specs, API contracts, deployment
├── PROJECT_STATUS.md       # Incremental phase delivery status
└── README.md
```

---

## Quickstart

### 1. Backend (Local Node.js v24)

```bash
cd apps/api
npm install
npm test
npm run dev
```

### 2. Mobile App (Built in GitHub Actions)

No local Flutter installation is required:
1. Push code to your GitHub repository.
2. In the GitHub repository, open the **Actions** tab.
3. The **Flutter Android Build** workflow automatically runs tests and builds the debug APK.
4. Download the generated `tradeverse-mobile-debug-apk` artifact.

---

## Documentation

- [System Architecture](file:///docs/ARCHITECTURE.md)
- [Stitch Integration & Design System](file:///docs/STITCH_INTEGRATION.md)
- [API Specifications](file:///docs/API.md)
- [Deployment & CI/CD Guide](file:///docs/DEPLOYMENT.md)
- [Project Status Tracker](file:///PROJECT_STATUS.md)
