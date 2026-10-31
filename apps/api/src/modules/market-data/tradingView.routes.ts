import express, { Request, Response } from 'express';

export const tradingViewRouter = express.Router();

export function resolveTradingViewSymbol(symbol: string): string {
  const clean = (symbol || 'RELIANCE').trim().toUpperCase();
  if (clean.includes('BTC')) return 'BINANCE:BTCUSDT';
  if (clean.includes('ETH')) return 'BINANCE:ETHUSDT';
  if (clean.includes('SOL')) return 'BINANCE:SOLUSDT';
  if (clean.includes('DOGE')) return 'BINANCE:DOGEUSDT';
  if (clean.includes('BNB')) return 'BINANCE:BNBUSDT';
  if (clean.includes('XRP')) return 'BINANCE:XRPUSDT';

  if (clean === 'NIFTY 50' || clean === 'NIFTY') return 'NSE:NIFTY';
  if (clean === 'BANKNIFTY') return 'NSE:BANKNIFTY';
  if (clean === 'FINNIFTY') return 'NSE:FINNIFTY';
  if (clean === 'SENSEX') return 'BSE:SENSEX';

  if (clean.includes('GOLD')) return 'MCX:GOLD1!';
  if (clean.includes('SILVER')) return 'MCX:SILVER1!';
  if (clean.includes('CRUDE')) return 'MCX:CRUDEOIL1!';
  if (clean.includes('NATURALGAS')) return 'MCX:NATURALGAS1!';

  const usEquities = ['AAPL', 'NVDA', 'TSLA', 'MSFT', 'GOOGL', 'AMZN', 'META', 'NFLX', 'AMD', 'COIN', 'QQQ'];
  if (usEquities.includes(clean)) return `NASDAQ:${clean}`;
  if (clean === 'SPY') return 'AMEX:SPY';

  // Default to National Stock Exchange (NSE) for Indian Equities
  return `NSE:${clean}`;
}

// GET /api/v1/market-data/tradingview/symbol/:symbol or /api/v1/tradingview/symbol/:symbol
tradingViewRouter.get('/symbol/:symbol', (req: Request, res: Response) => {
  const symbol = (Array.isArray(req.params.symbol) ? req.params.symbol[0] : req.params.symbol) as string;
  const tvSymbol = resolveTradingViewSymbol(symbol);
  res.status(200).json({
    success: true,
    data: {
      inputSymbol: symbol,
      tradingViewSymbol: tvSymbol,
      widgetUrl: `/tradingview?symbol=${encodeURIComponent(symbol)}`,
      chartUrl: `/tradingview?symbol=${encodeURIComponent(symbol)}`,
    },
  });
});

// GET /tradingview, /chart, or /api/v1/market-data/tradingview/widget
tradingViewRouter.get(['/', '/widget'], (req: Request, res: Response) => {
  const symbol = (req.query.symbol as string) || 'RELIANCE';
  const tvSymbol = resolveTradingViewSymbol(symbol);
  const interval = (req.query.interval as string) || '15';

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>TradeVerse AI — TradingView Chart & Account Manager</title>
  <script type="text/javascript" src="https://s3.tradingview.com/tv.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: #0b0e14;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      flex-direction: column;
      height: 100vh;
      overflow: hidden;
    }
    header {
      background: #121721;
      border-bottom: 1px solid #1e293b;
      padding: 10px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-shrink: 0;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 15px;
      font-weight: 700;
      color: #38bdf8;
    }
    .badge {
      background: rgba(16, 185, 129, 0.15);
      color: #10b981;
      padding: 2px 8px;
      border-radius: 4px;
      font-size: 11px;
      font-weight: 600;
    }
    .order-btn-buy {
      background: #00D09C;
      color: #0b0e14;
      font-weight: 700;
      border: none;
      padding: 6px 14px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 12px;
      transition: all 0.2s ease;
    }
    .order-btn-buy:hover {
      background: #00e6aa;
      transform: translateY(-1px);
    }
    .order-btn-sell {
      background: #EB5B5B;
      color: #ffffff;
      font-weight: 700;
      border: none;
      padding: 6px 14px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 12px;
      transition: all 0.2s ease;
    }
    .order-btn-sell:hover {
      background: #ff6b6b;
      transform: translateY(-1px);
    }
    .live-pnl-pill {
      background: rgba(0, 208, 156, 0.12);
      border: 1px solid rgba(0, 208, 156, 0.35);
      color: #00D09C;
      padding: 4px 12px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .live-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: #00D09C;
      animation: pulseDot 1.5s infinite;
    }
    @keyframes pulseDot {
      0% { opacity: 0.4; transform: scale(0.9); }
      50% { opacity: 1; transform: scale(1.2); }
      100% { opacity: 0.4; transform: scale(0.9); }
    }
    .quick-symbols {
      display: flex;
      gap: 6px;
      overflow-x: auto;
    }
    .sym-btn {
      background: #1e293b;
      color: #cbd5e1;
      border: 1px solid #334155;
      padding: 4px 10px;
      border-radius: 6px;
      font-size: 11px;
      cursor: pointer;
      font-weight: 600;
      transition: all 0.15s ease;
    }
    .sym-btn:hover, .sym-btn.active {
      background: #2563eb;
      color: #ffffff;
      border-color: #3b82f6;
    }
    #chart_wrapper {
      flex: 1 1 65%;
      min-height: 250px;
      position: relative;
    }
    #tv_chart_container {
      width: 100%;
      height: 100%;
    }
    #account_manager_panel {
      flex: 1 1 35%;
      min-height: 180px;
      background: #0f172a;
      border-top: 2px solid #1e293b;
      display: flex;
      flex-direction: column;
    }
    .am-header {
      background: #121827;
      border-bottom: 1px solid #1e293b;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 16px;
    }
    .am-tabs {
      display: flex;
      gap: 2px;
    }
    .am-tab {
      padding: 8px 14px;
      font-size: 12px;
      font-weight: 600;
      color: #94a3b8;
      cursor: pointer;
      border-bottom: 2px solid transparent;
      transition: all 0.15s ease;
    }
    .am-tab.active {
      color: #38bdf8;
      border-bottom-color: #38bdf8;
      background: rgba(56, 189, 248, 0.05);
    }
    .am-status {
      font-size: 11px;
      color: #64748b;
    }
    .am-content {
      flex: 1;
      overflow-y: auto;
      padding: 8px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 12px;
    }
    th {
      text-align: left;
      padding: 8px 10px;
      color: #64748b;
      border-bottom: 1px solid #1e293b;
      font-weight: 600;
      text-transform: uppercase;
      font-size: 10px;
    }
    td {
      padding: 8px 10px;
      border-bottom: 1px solid #1e293b;
      color: #e2e8f0;
    }
    tr:hover td {
      background: rgba(255, 255, 255, 0.02);
    }
    .row-button {
      background: #1e293b;
      color: #38bdf8;
      border: 1px solid #334155;
      padding: 3px 8px;
      border-radius: 4px;
      font-size: 11px;
      cursor: pointer;
      font-weight: 600;
    }
    .row-button:hover {
      background: #2563eb;
      color: #fff;
    }
    .pill-green {
      background: rgba(16, 185, 129, 0.15);
      color: #10b981;
      padding: 2px 6px;
      border-radius: 4px;
      font-weight: 600;
      font-size: 10px;
    }
    .pill-red {
      background: rgba(239, 68, 68, 0.15);
      color: #ef4444;
      padding: 2px 6px;
      border-radius: 4px;
      font-weight: 600;
      font-size: 10px;
    }
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <span>TradeVerse AI — TradingView Charting Terminal</span>
      <span class="badge">LIVE TRACKING</span>
    </div>
    <div class="quick-symbols">
      <button class="sym-btn" onclick="switchSymbol('NSE:NIFTY')">NIFTY 50</button>
      <button class="sym-btn" onclick="switchSymbol('NSE:BANKNIFTY')">BANKNIFTY</button>
      <button class="sym-btn" onclick="switchSymbol('NSE:RELIANCE')">RELIANCE</button>
      <button class="sym-btn" onclick="switchSymbol('NSE:ADANIENT')">ADANIENT</button>
      <button class="sym-btn" onclick="switchSymbol('BINANCE:BTCUSDT')">BTC/USDT</button>
      <button class="sym-btn" onclick="switchSymbol('NASDAQ:TSLA')">TSLA</button>
      <button class="sym-btn" onclick="switchSymbol('MCX:GOLD1!')">GOLD (MCX)</button>
    </div>
    <div style="display: flex; align-items: center; gap: 10px;">
      <div class="live-pnl-pill" id="header_pnl_badge">
        <span class="live-dot"></span>
        <span id="header_pnl_text">LIVE P&L: +₹744.00 (+0.54%)</span>
      </div>
      <button class="order-btn-buy" onclick="quickOrder('BUY')">+ BUY (LONG)</button>
      <button class="order-btn-sell" onclick="quickOrder('SELL')">- SELL (SHORT)</button>
    </div>
  </header>

  <div id="toast" style="display:none; position:fixed; top:70px; right:20px; z-index:9999; background:#1e293b; border:2px solid #00D09C; border-radius:10px; padding:12px 18px; color:#fff; box-shadow:0 10px 25px rgba(0,0,0,0.5);">
    <strong id="toast_title" style="color:#00D09C; display:block; font-size:14px;">Order Booked Successfully! 🎉</strong>
    <span id="toast_msg" style="font-size:12px; color:#cbd5e1;"></span>
  </div>

  <div id="chart_wrapper">
    <div id="tv_chart_container"></div>
  </div>

  <div id="account_manager_panel">
    <div class="am-header">
      <div class="am-tabs">
        <div class="am-tab active" onclick="switchTab('custom_page')">Custom Page (Account Manager)</div>
        <div class="am-tab" onclick="switchTab('orders')">Simulated Orders (Booked)</div>
        <div class="am-tab" onclick="switchTab('positions')">Live Positions & P&L</div>
        <div class="am-tab" onclick="switchTab('balance')">Account Balance</div>
      </div>
      <div class="am-status" id="update_status">Live Dynamic Updates: Active (every 5s)</div>
    </div>
    <div class="am-content" id="tab_content">
      <!-- Dynamic table rendered by JS -->
    </div>
  </div>

  <script>
    let currentSymbol = "${tvSymbol}";
    let tvWidget = null;

    function initTradingView(sym) {
      currentSymbol = sym;
      const container = document.getElementById('tv_chart_container');
      if (!container) return;
      container.innerHTML = '';

      if (typeof TradingView !== 'undefined' && TradingView.widget) {
        try {
          tvWidget = new TradingView.widget({
            "autosize": true,
            "symbol": sym,
            "interval": "${interval}",
            "timezone": "Asia/Kolkata",
            "theme": "dark",
            "style": "1",
            "locale": "en",
            "toolbar_bg": "#0f172a",
            "enable_publishing": false,
            "withdateranges": true,
            "hide_side_toolbar": false,
            "allow_symbol_change": true,
            "details": true,
            "hotlist": true,
            "calendar": true,
            "studies": [
              "RSI@tv-basicstudies",
              "MASimple@tv-basicstudies",
              "MACD@tv-basicstudies",
              "BollingerBands@tv-basicstudies"
            ],
            "container_id": "tv_chart_container"
          });
          return;
        } catch (e) {
          console.warn("TradingView widget init warning, falling back to embedded iframe:", e);
        }
      }

      // 100% Reliable fallback to TradingView Advanced Real-Time Chart Widget Iframe
      container.innerHTML = '<iframe src="https://s.tradingview.com/widgetembed/?symbol=' + encodeURIComponent(sym) + '&interval=${interval}&theme=dark&style=1&timezone=Asia%2FKolkata&locale=en" style="width:100%;height:100%;border:none;"></iframe>';
    }

    // Initial launch
    setTimeout(() => initTradingView(currentSymbol), 100);

    function switchSymbol(sym) {
      currentSymbol = sym;
      if (tvWidget && typeof tvWidget.activeChart === 'function') {
        try {
          tvWidget.activeChart().setSymbol(sym);
        } catch (_) {
          initTradingView(sym);
        }
      } else {
        initTradingView(sym);
      }
    }

    // -------------------------------------------------------------
    // TradingView Account Manager Custom Page Implementation
    // -------------------------------------------------------------
    class CustomBroker {
      constructor() {
        // Step 1: Set up a delegate in constructor
        this._customPageData = [
          { id: 1, symbol: "NSE:RELIANCE", customTextOne: "1 - Core Holding", customTextTwo: 88 },
          { id: 2, symbol: "NSE:ADANIENT", customTextOne: "2 - Momentum Long", customTextTwo: 64 },
          { id: 3, symbol: "BINANCE:BTCUSDT", customTextOne: "3 - Crypto Breakout", customTextTwo: 95 },
          { id: 4, symbol: "NASDAQ:TSLA", customTextOne: "4 - EV Swing", customTextTwo: 72 },
        ];
        this._positions = [
          { symbol: "NSE:RELIANCE", qty: 10, buyPrice: 2945.50, ltp: 2958.20, pnl: 127.00, pnlPct: "+0.43%" },
          { symbol: "BINANCE:BTCUSDT", qty: 1, buyPrice: 77568.00, ltp: 77810.00, pnl: 242.00, pnlPct: "+0.31%" },
          { symbol: "NSE:ADANIENT", qty: 15, buyPrice: 2840.00, ltp: 2865.00, pnl: 375.00, pnlPct: "+0.88%" },
        ];
        this._orders = [
          { id: "ord_001", symbol: "NSE:NIFTY", side: "BUY", qty: 50, price: 24852.15, status: "FILLED", type: "MIS" },
          { id: "ord_002", symbol: "BINANCE:BTCUSDT", side: "BUY", qty: 1, price: 77568.00, status: "FILLED", type: "MARKET" },
          { id: "ord_003", symbol: "NSE:ADANIENT", side: "BUY", qty: 10, price: 2840.00, status: "FILLED", type: "MIS" },
        ];

        // Step 3: Trigger dynamic updates every 5 seconds
        setInterval(() => {
          this.triggerCustomPageUpdate();
        }, 5000);
      }

      // Step 3: Create function for dynamic data updates
      triggerCustomPageUpdate() {
        const pool = ["NSE:TCS", "NSE:HDFCBANK", "NSE:INFY", "NSE:SBIN", "NASDAQ:AAPL", "NASDAQ:NVDA"];
        const sym = pool[Math.floor(Math.random() * pool.length)];
        const newId = this._customPageData.length + 1;
        const newItem = {
          id: newId,
          symbol: sym,
          customTextOne: \`\${newId} - Algorithmic Alert\`,
          customTextTwo: Math.round(Math.random() * 100),
        };
        this._customPageData.unshift(newItem);
        if (this._customPageData.length > 15) this._customPageData.pop();

        if (activeTab === 'custom_page') renderCustomPage();
        if (activeTab === 'positions') renderPositions();
      }
    }

    const broker = new CustomBroker();
    let activeTab = 'custom_page';

    function switchTab(tab) {
      activeTab = tab;
      document.querySelectorAll('.am-tab').forEach(el => el.classList.remove('active'));
      const activeEl = Array.from(document.querySelectorAll('.am-tab')).find(el => el.getAttribute('onclick').includes(tab));
      if (activeEl) activeEl.classList.add('active');

      if (tab === 'custom_page') renderCustomPage();
      else if (tab === 'orders') renderOrders();
      else if (tab === 'positions') renderPositions();
      else if (tab === 'balance') renderBalance();
    }

    // Step 4 & 5: Define columns & implement chart loading on click (rowButton)
    function renderCustomPage() {
      const container = document.getElementById('tab_content');
      let html = \`
        <table>
          <thead>
            <tr>
              <th>Symbol (Click to Load)</th>
              <th>Signal / Strategy</th>
              <th>Confidence Score</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
      \`;
      broker._customPageData.forEach(item => {
        html += \`
          <tr>
            <td>
              <button class="row-button" onclick="switchSymbol('\${item.symbol}')">
                \${item.symbol}
              </button>
            </td>
            <td>\${item.customTextOne}</td>
            <td><strong style="color: #38bdf8;">\${item.customTextTwo}%</strong></td>
            <td><span class="pill-green">ACTIVE</span></td>
          </tr>
        \`;
      });
      html += '</tbody></table>';
      container.innerHTML = html;
    }

    function renderOrders() {
      const container = document.getElementById('tab_content');
      let html = \`
        <table>
          <thead>
            <tr>
              <th>Order ID</th>
              <th>Symbol</th>
              <th>Side</th>
              <th>Quantity</th>
              <th>Executed Price</th>
              <th>Product</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
      \`;
      broker._orders.forEach(o => {
        html += \`
          <tr>
            <td>\${o.id}</td>
            <td><button class="row-button" onclick="switchSymbol('\${o.symbol}')">\${o.symbol}</button></td>
            <td><span class="\${o.side === 'BUY' ? 'pill-green' : 'pill-red'}">\${o.side}</span></td>
            <td>\${o.qty}</td>
            <td>₹\${o.price.toLocaleString()}</td>
            <td>\${o.type}</td>
            <td><span class="pill-green">● \${o.status}</span></td>
          </tr>
        \`;
      });
      html += '</tbody></table>';
      container.innerHTML = html;
    }

    function renderPositions() {
      const container = document.getElementById('tab_content');
      let html = \`
        <table>
          <thead>
            <tr>
              <th>Symbol</th>
              <th>Quantity</th>
              <th>Avg Buy Price</th>
              <th>LTP</th>
              <th>Unrealized P&L</th>
              <th>Return %</th>
            </tr>
          </thead>
          <tbody>
      \`;
      broker._positions.forEach(p => {
        html += \`
          <tr>
            <td><button class="row-button" onclick="switchSymbol('\${p.symbol}')">\${p.symbol}</button></td>
            <td>\${p.qty}</td>
            <td>₹\${p.buyPrice.toFixed(2)}</td>
            <td>₹\${p.ltp.toFixed(2)}</td>
            <td style="color: #10b981; font-weight: bold;">+₹\${p.pnl.toFixed(2)}</td>
            <td><span class="pill-green">\${p.pnlPct}</span></td>
          </tr>
        \`;
      });
      html += '</tbody></table>';
      container.innerHTML = html;
    }

    function renderBalance() {
      const container = document.getElementById('tab_content');
      container.innerHTML = \`
        <div style="display: flex; gap: 20px; padding: 16px;">
          <div style="background: #1e293b; padding: 16px; border-radius: 8px; flex: 1;">
            <div style="font-size: 11px; color: #94a3b8;">Total Virtual Portfolio Value</div>
            <div style="font-size: 24px; font-weight: bold; color: #38bdf8; margin-top: 4px;">₹10,24,560.00</div>
          </div>
          <div style="background: #1e293b; padding: 16px; border-radius: 8px; flex: 1;">
            <div style="font-size: 11px; color: #94a3b8;">Available Sandbox Cash</div>
            <div style="font-size: 24px; font-weight: bold; color: #10b981; margin-top: 4px;">₹8,75,200.00</div>
          </div>
          <div style="background: #1e293b; padding: 16px; border-radius: 8px; flex: 1;">
            <div style="font-size: 11px; color: #94a3b8;">Total Unrealized P&L</div>
            <div style="font-size: 24px; font-weight: bold; color: #10b981; margin-top: 4px;">+₹24,560.00 (+2.45%)</div>
          </div>
        </div>
      \`;
    }

    function quickOrder(side) {
      const sym = currentSymbol;
      const isBuy = side === 'BUY';
      const orderId = 'ord_' + Math.floor(Math.random() * 9000 + 1000);
      const estPrice = sym.includes('BTC') ? 77568.00 : (sym.includes('ADANI') ? 2865.00 : (sym.includes('RELIANCE') ? 2958.00 : 24850.00));
      const newOrder = {
        id: orderId,
        symbol: sym,
        side: side,
        qty: 1,
        price: estPrice,
        status: "FILLED",
        type: "MARKET"
      };
      broker._orders.unshift(newOrder);

      let pos = broker._positions.find(p => p.symbol === sym);
      if (pos) {
        pos.qty += (isBuy ? 1 : -1);
      } else {
        broker._positions.unshift({
          symbol: sym,
          qty: 1,
          buyPrice: estPrice,
          ltp: estPrice,
          pnl: 0.00,
          pnlPct: "+0.00%"
        });
      }

      showToast("Order Booked Successfully! 🎉", side + " 1 Lot of " + sym + " @ ₹" + estPrice.toLocaleString() + " filled!");
      if (activeTab === 'orders') renderOrders();
      if (activeTab === 'positions') renderPositions();
      updateHeaderPnl();
    }

    function showToast(title, msg) {
      const t = document.getElementById('toast');
      document.getElementById('toast_title').innerText = title;
      document.getElementById('toast_msg').innerText = msg;
      t.style.display = 'block';
      setTimeout(() => { t.style.display = 'none'; }, 4000);
    }

    function updateHeaderPnl() {
      let totalPnl = 0;
      let totalInvested = 0;
      broker._positions.forEach(p => {
        totalPnl += p.pnl;
        totalInvested += p.buyPrice * Math.abs(p.qty);
      });
      const pct = totalInvested > 0 ? ((totalPnl / totalInvested) * 100).toFixed(2) : "0.00";
      const isPos = totalPnl >= 0;
      const badge = document.getElementById('header_pnl_badge');
      const text = document.getElementById('header_pnl_text');
      if (badge && text) {
        text.innerText = "LIVE P&L: " + (isPos ? '+' : '') + "₹" + totalPnl.toFixed(2) + " (" + (isPos ? '+' : '') + pct + "%)";
        badge.style.color = isPos ? '#00D09C' : '#EB5B5B';
        badge.style.borderColor = isPos ? 'rgba(0, 208, 156, 0.4)' : 'rgba(235, 91, 91, 0.4)';
      }
    }

    // Dynamic price tick pulse for positions
    setInterval(() => {
      broker._positions.forEach(p => {
        const delta = (Math.random() - 0.48) * (p.ltp * 0.001);
        p.ltp = +(p.ltp + delta).toFixed(2);
        p.pnl = +((p.ltp - p.buyPrice) * p.qty).toFixed(2);
        const pct = ((p.pnl / (p.buyPrice * Math.abs(p.qty))) * 100).toFixed(2);
        p.pnlPct = (pct >= 0 ? '+' : '') + pct + '%';
      });
      if (activeTab === 'positions') renderPositions();
      updateHeaderPnl();
    }, 2000);

    window.addEventListener('load', () => {
      initTradingView(currentSymbol);
      renderCustomPage();
      updateHeaderPnl();
    });
  </script>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html');
  res.send(html);
});
