# TradeVerse AI — Autonomous Paper Trading Platform

[![Flutter CI](https://github.com/Abhinavkunnummal/VirtualTradingApp/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/Abhinavkunnummal/VirtualTradingApp/actions/workflows/flutter-ci.yml)
[![Flutter Android Build](https://github.com/Abhinavkunnummal/VirtualTradingApp/actions/workflows/flutter-android-build.yml/badge.svg)](https://github.com/Abhinavkunnummal/VirtualTradingApp/actions/workflows/flutter-android-build.yml)
[![Backend CI](https://github.com/Abhinavkunnummal/VirtualTradingApp/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/Abhinavkunnummal/VirtualTradingApp/actions/workflows/backend-ci.yml)

TradeVerse AI is a paper-trading and market simulation platform designed for high-density financial ergonomics, simulated institutional order routing, multi-asset markets (NSE/BSE, MCX commodities, US equities, and 24/7 crypto), and educational AI copilot scenarios.

---

## Key Highlights

- **Visual Fidelity**: Fully implemented from the Google Stitch design system (`projects/6279083996241232485`), featuring institutional dark ergonomics, tabular figures, and 49 screen states.
- **Frontend Architecture**: Flutter (Material 3, Riverpod, GoRouter, Dio, Socket.IO client, Flutter Secure Storage).
- **Backend Architecture**: Node.js, Express, TypeScript, MongoDB Atlas, Mongoose, Socket.IO real-time engine, Zod validation.
- **Paper-Trading Simulation Engine**: Deterministic simulated execution supporting Market, Limit, SL, and SL-M orders, leverage/margin simulation (Intraday MIS 5x, Delivery CNC), fees, taxes, and slippage calculations.
- **Zero-Local-Flutter Cloud Builds**: Built entirely via GitHub Actions on cloud runners. Generates downloadable Android APKs without requiring Flutter or Android Studio on your local machine.

---

## Monorepo Architecture

```
VirtualTradingApp/
├── apps/
│   ├── mobile/             # Flutter Mobile Application (Material 3 + Riverpod + GoRouter)
│   └── api/                # Node.js + Express + TypeScript Backend
├── packages/
│   └── shared/             # Shared TypeScript API Contracts & Schemas
├── .github/
│   └── workflows/          # GitHub Actions CI/CD (Flutter CI, Android APK, Backend CI)
├── docs/                   # Architecture, Stitch specs, API contracts, deployment, mobile QA
├── PROJECT_STATUS.md       # Incremental phase delivery status & verification log
└── README.md
```

---

## Cloud CI/CD Status & Android APK Download

Every commit pushed to `main` is automatically verified across all three cloud runners:

| Workflow | Cloud Runner | Status | Output |
| :--- | :--- | :---: | :--- |
| **Backend CI** | Ubuntu LTS • Node.js 22 LTS | **Passed** | 82/82 Jest tests passing across 11 test suites, TypeScript clean |
| **Flutter CI** | Ubuntu LTS • Flutter 3.29.0 | **Passed** | Formatting, strict analysis (`strict-casts`, `strict-inference`), 7 widget test suites passing |
| **Flutter Android Build** | Ubuntu LTS • JDK 17 • Flutter 3.29.0 | **Passed** | **`app-debug.apk`** (86.0 MB) generated and uploaded as artifact |

### Cloud Hosting on Render
The backend is pre-configured for 1-click cloud deployment on **Render** via [`render.yaml`](file:///render.yaml):
- Automated Blueprint provisioning with free-tier Node.js web service.
- Cryptographic JWT secrets generated on the fly.
- Zero-downtime healthcheck monitoring on `/health`.
- See the [Production Deployment Guide](file:///docs/DEPLOYMENT.md) for step-by-step instructions.

### How to Install the Android App
1. Go to the [Flutter Android Build Workflow](https://github.com/Abhinavkunnummal/VirtualTradingApp/actions/workflows/flutter-android-build.yml).
2. Click on the latest successful run.
3. Under the **Artifacts** section at the bottom, click **`tradeverse-mobile-debug-apk`**.
4. Unzip and install `app-debug.apk` on any Android smartphone or tablet (Android 7.0 / API 24+).

---

## Local Backend Verification

While Flutter builds and tests in GitHub Actions cloud runners, the Node.js backend can be tested locally using Node.js:

```bash
# 1. Install dependencies & build shared contracts
npm --prefix packages/shared/api-contracts run build

# 2. Run backend test suite (11 suites, 82 tests)
npm --prefix apps/api test

# 3. Start local development server
npm --prefix apps/api run dev
```

---

## Documentation Links

- [System Architecture](file:///docs/ARCHITECTURE.md)
- [Stitch Design Integration](file:///docs/STITCH_INTEGRATION.md)
- [API Specifications](file:///docs/API.md)
- [Production Deployment Guide](file:///docs/DEPLOYMENT.md)
- [Mobile QA Smoke-Test Checklist](file:///docs/MOBILE_QA_CHECKLIST.md)
- [Phase Status & Audit Findings](file:///PROJECT_STATUS.md)
