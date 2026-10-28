# TradeVerse AI — Google Stitch Integration & Design System

## Project Reference

- **Project ID**: `projects/6279083996241232485`
- **Project Title**: TradeVerse AI Paper Trading Mobile
- **Device Target**: Mobile (High-density 390x844pt / 393x852pt viewport)
- **Origin**: Google Stitch (`TEXT_TO_UI_PRO`)
- **Total Screens**: 49 generated screens & interactive states

---

## Design System Tokens

The mobile application follows institutional terminal ergonomics softened for approachable financial intelligence.

### 1. Color Palette

```dart
class AppColors {
  // Canvas & Surfaces
  static const Color surfaceCanvas = Color(0xFF101419);
  static const Color surfaceDim = Color(0xFF101419);
  static const Color surfaceBright = Color(0xFF36393F);
  
  // Surface Container Hierarchy (Tonal Elevation)
  static const Color surfaceLowest = Color(0xFF0A0E13);
  static const Color surfaceLow = Color(0xFF181C21);
  static const Color surfaceContainer = Color(0xFF1C2025);
  static const Color surfaceHigh = Color(0xFF262A30);
  static const Color surfaceHighest = Color(0xFF31353B);
  
  // Brand & Accent (Electric Violet)
  static const Color primary = Color(0xFFC4C0FF);
  static const Color primaryContainer = Color(0xFF8781FF);
  static const Color primaryBrand = Color(0xFF6C63FF);
  static const Color onPrimary = Color(0xFF2000A4);
  static const Color onPrimaryContainer = Color(0xFF1B0091);
  
  // Market Dynamics: Bullish / Gain / Buy
  static const Color secondary = Color(0xFF4ADF9C);
  static const Color secondaryContainer = Color(0xFF02BA7A);
  static const Color onSecondary = Color(0xFF003822);
  static const Color bullGreen = Color(0xFF25C685);
  
  // Market Dynamics: Bearish / Loss / Sell
  static const Color tertiary = Color(0xFFFFB2B6);
  static const Color tertiaryContainer = Color(0xFFF9586C);
  static const Color onTertiary = Color(0xFF68001A);
  static const Color bearRed = Color(0xFFFF5C70);
  
  // Alerts & Errors
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  
  // Text & Outline
  static const Color onSurface = Color(0xFFE0E2EA);
  static const Color onSurfaceVariant = Color(0xFFC7C4D8);
  static const Color outline = Color(0xFF918FA1);
  static const Color outlineVariant = Color(0xFF464555);
  static const Color borderSubtle = Color(0xFF283342);
}
```

### 2. Typography Tokens

Typeface: **Inter** with tabular number figures (`tnum`, `zero`) for all financial prices, P&L, ticks, and quantities.

| Style Name | Font Size | Line Height | Weight | Letter Spacing |
|---|---|---|---|---|
| `display-lg` | 32px | 40px | 700 (Bold) | -0.03em |
| `display-sm` | 24px | 32px | 700 (Bold) | -0.02em |
| `headline-md` | 20px | 28px | 600 (Semi-Bold) | -0.015em |
| `headline-sm` | 16px | 24px | 600 (Semi-Bold) | -0.01em |
| `body-lg` | 15px | 22px | 400 (Regular) | -0.005em |
| `body-md` | 13px | 18px | 400 (Regular) | 0.0em |
| `label-md` | 12px | 16px | 500 (Medium) | +0.01em |
| `label-sm` | 11px | 14px | 600 (Semi-Bold) | +0.04em |
| `numeric-ticker` | 22px | 28px | 600 (Semi-Bold) | -0.02em (Tabular) |
| `numeric-table` | 13px | 18px | 500 (Medium) | 0.0em (Tabular) |

### 3. Radii & Spacing

- **Corner Radii**:
  - `sm`: 4px (inputs, badges, small buttons)
  - `md`: 8px (standard cards, chips)
  - `lg`: 12px (modular cards, bottom sheets)
  - `xl`: 16px (major panels, dialogs)
  - `full`: 9999px (capsule tags, floating action triggers)
- **Spacing Micro-Grid**: 4px micro-grid
  - `space-xs`: 4px
  - `space-sm`: 8px
  - `space-md`: 12px
  - `space-lg`: 16px
  - `space-xl`: 24px
  - `margin`: 16px
  - `gutter`: 12px

---

## Catalog of 49 Stitch Screens & Route Mappings

| # | Screen Label | Stitch Screen ID | Flutter Route | Feature Module |
|---|---|---|---|---|
| 1 | IPO & Primary Market Simulator | `0373364aa6734aa9befdb73bae2e7d53` | `/markets/ipo` | Markets / Primary |
| 2 | Sign-Up & Virtual Account Creation | `09618b7f315b45c8a0789bb7076da1eb` | `/auth/register` | Authentication |
| 3 | Crypto 24/7 Simulator & Orderbook | `0d13864b78de400aad0d81c99d4fb7d3` | `/markets/crypto` | Markets / Crypto |
| 4 | Watchlists & Alerts Manager | `1000027951ff4fa4a204e9d906b017bd` | `/markets/watchlists` | Watchlists |
| 5 | Full-Screen Advanced Charting | `172b968cfc694865bc0d2c1906dea12a` | `/trade/chart-fullscreen` | Trade / Charting |
| 6 | Asset Details & Chart | `200a1db0a0774fd195279f621a10b589` | `/asset/:symbol` | Asset Overview |
| 7 | Profile, Learning & Settings | `20444a6d4b91454a90a9d5f4e0a57adb` | `/profile` | Profile & Config |
| 8 | PineScript & Custom Indicator IDE | `346c75454ffd40a3ba941410f5ec438d` | `/tools/pinescript` | Algorithmic Lab |
| 9 | Simulated Brokerage & Charges Audit | `37defb1ff3cf49a3b6e4df82b8ec2163` | `/trade/charges-audit` | Trade / Execution |
| 10 | Markets & Asset Discovery | `3bdf9cef5aa843cc9cb62cfdbc9afe02` | `/markets` | Primary Nav (Tab 2) |
| 11 | Notifications & Market Alerts Hub | `3d3b98da0d9e484387c01776d59a4bc3` | `/notifications` | Notifications |
| 12 | VIP Trading Mentor Desk & Masterclasses | `405f8f462f814142bbff310011d636e7` | `/learning/mentor` | Learning / Academy |
| 13 | Risk Management & Position Guard | `4b2f9ce9f4d44284beef3b433a6f85f4` | `/portfolio/risk-guard` | Risk Engine |
| 14 | US Stocks & Extended Hours Trading | `4b8055920c6d44a5af3167c89e1972e9` | `/markets/us-stocks` | Markets / US Equities |
| 15 | AI Trading Signals & Copilot Setups | `4ccc443f8c174c88972ca90536b951c9` | `/ai-copilot/signals` | AI Assistant |
| 16 | Multi-Account Sandbox & Challenge Switcher | `4cf2f3b5705846ccae9bac76273845f3` | `/portfolio/sandboxes` | Paper Accounts |
| 17 | Portfolio & Analytics | `583a1d4f548a47938430c7ceffa9443f` | `/portfolio` | Primary Nav (Tab 5) |
| 18 | Commodity & MCX Futures Trading | `5d72cc847fbc4bd39884af298b0ba3bb` | `/markets/commodities` | Markets / MCX |
| 19 | News & Market Sentiment | `60272a578e794e198431ba03dd244d80` | `/news` | Market News |
| 20 | Community Leaderboard & Profiles | `61e049238dd54df3bb4338d152b52b06` | `/community/leaderboard` | Community / Social |
| 21 | Home Dashboard | `662964398ba748a49d3a26d6add70555` | `/` | Primary Nav (Tab 1) |
| 22 | Sector & Market Heatmap Scanner | `669c07274dbb458a9a2e9783298e35ab` | `/markets/heatmap` | Market Scanners |
| 23 | Beginner Learning & Practice Lab | `6a6880aba39e4cfc963c7481e5294dd8` | `/learning/lab` | Learning / Academy |
| 24 | Onboarding & Virtual Capital Setup | `70e127d35201463a9b1a6d9238a2229c` | `/auth/onboarding` | Onboarding |
| 25 | Institutional Flash News & Live Squawk | `71ed0efcc3094e789e3972fb0a48a09d` | `/news/squawk` | News / Audio Feed |
| 26 | Institutional Order Flow & Level 3 Depth | `7454ccc3803544728d25276b52b1280f` | `/trade/order-flow` | Trade / Depth |
| 27 | Tax P&L Report with Interactive Regime | `7e52b4109f514b938c27c6cdbc311ab6` | `/portfolio/tax-report` | Portfolio / Tax |
| 28 | Community & Social Feed | `7f57a4024e6c4f42819ccea8fff53f08` | `/community` | Primary Nav (Tab 4) |
| 29 | Strategy Backtesting & Scenario Lab | `85280564b41647a19f3ad8ddbf86d4f2` | `/tools/backtest` | Quant Tools |
| 30 | Strategy Payoff & Multi-Leg Builder | `8af54354efa84978b8f0a7c4335f53e5` | `/trade/strategy-builder` | Derivatives |
| 31 | Social Copy Trading & Copier Vault | `912edb0733a7457f85bc23956f1077e7` | `/community/copy-trading` | Social Trading |
| 32 | Algo Trading & Bot Builder | `928d359e55f5480883dd4d1e9c7cb8fe` | `/tools/algo-bots` | Algo Engine |
| 33 | Virtual Capital & Sandbox Funds Manager | `98fb5182713a4d6db220017a3fc7ddb1` | `/portfolio/funds` | Funds Management |
| 34 | Options Chain & Derivatives | `9d4edb61d36a4f548e6394b39b9cd848` | `/markets/options-chain` | Derivatives / Options |
| 35 | Community Discussion Room: Nifty Options | `a2855f0f140f48f8bfe90e7957fbe3ef` | `/community/room/:roomId` | Chat & Rooms |
| 36 | Tax P&L Report with Regime Calculator Drawer | `a67024fc95e3476bbf500c7b669fbecc` | `/portfolio/tax-drawer` | Portfolio / Tax |
| 37 | Order Ticket & Execution | `a70d96b9d07b499bba6ddc64b08193f1` | `/trade` | Primary Nav (Tab 3) |
| 38 | Quant Strategy Rule Engine & Builder | `aad33b29c0614a8281622d53692f2646` | `/tools/rule-engine` | Quant Engine |
| 39 | Design System Instance Spec | `assets_802d9200fcf9497c9fc2d7810b677162` | N/A | Design Tokens Master |
| 40 | Advanced Performance & P&L Attribution | `b463d17d2450418195fb322528d60451` | `/portfolio/attribution` | Portfolio Analytics |
| 41 | Backtesting & Strategy Lab | `b91847b810b6403086ee2d11a51dd070` | `/tools/strategy-lab` | Quant Lab |
| 42 | Options Greeks Matrix & Multi-Strike | `bde1b5df44b1463b9264390d724230b8` | `/trade/options-greeks` | Derivatives / Greeks |
| 43 | Trade Journal & Performance Review | `c3d3f108f2284eb68c4476dc1316159b` | `/portfolio/journal` | Trade Journal |
| 44 | AI Trading Assistant | `c598ca68b11d4809a13c9356b7849e1b` | `/ai-assistant` | AI Assistant |
| 45 | Championship Battle Arena & Duels | `d62784b7b432485091fc4db9737305c8` | `/community/arena` | Gamification |
| 46 | Market Calendar & Earnings Hub | `d6d7a387bd2e4e4da985e92339b1de1f` | `/markets/calendar` | Market Calendar |
| 47 | Create Price Alert & Trigger | `e58df8b52f814915bb7d64894fa187d1` | `/markets/create-alert` | Alerts System |
| 48 | Trader Public Profile & Verified Track Record | `e9a8540b8cc04790bcfa903bb019a41d` | `/community/trader/:id` | Community Profiles |
| 49 | Trade Analytics & Tax P&L Report | `f65f579b1f6a4442ba50202392f11a06` | `/portfolio/analytics` | Analytics |

---

## Native Flutter Widget Conversion Protocol

1. **Containers**: Map Stitch HTML container classes (`surface-container-lowest`, `surface-container`, `surface-container-high`, `border-borderSubtle`) to Flutter `Container` or `Card` with `BoxDecoration` using `AppColors` and `Border.all(color: AppColors.borderSubtle, width: 1.0)`.
2. **Typography**: Enforce `fontFamily: 'Inter'` across all text styles, specifying `fontFeatures: [FontFeature.tabularFigures()]` for prices and quantities.
3. **Tabular Telemetry**: Ticker quotes, price badges, and P&L changes are encapsulated in dedicated reusable widgets (`TickerBadge`, `PriceDisplay`, `PnlIndicator`).
4. **Bottom Navigation**: Implemented via Flutter `StatefulShellRoute` in GoRouter preserving state across the 5 primary tabs with a custom bottom navigation bar matching Stitch's floating blur aesthetic.
