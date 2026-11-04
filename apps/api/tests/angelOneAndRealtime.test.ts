import { generateTOTP, AngelOneService } from '../src/modules/market-data/angelOne.service';
import { MarketDataService } from '../src/modules/market-data/marketData.service';
import { ChartStreamService } from '../src/modules/market-data/chartStream.service';
import { RealtimeMarketService } from '../src/modules/market-data/realtimeMarket.service';

describe('Angel One SmartAPI Provider & Real-Time Data Suite', () => {
  describe('TOTP Generation (RFC 6238)', () => {
    it('should generate a 6-digit numeric TOTP string from a base32 secret', () => {
      const secret = 'JBSWY3DPEHPK3PXP'; // Standard test secret (ASCII: "12345678901234567890")
      const totp = generateTOTP(secret);
      expect(totp).toMatch(/^\d{6}$/);
      expect(totp.length).toBe(6);
    });

    it('should handle spaces, dashes and case insensitivity in base32 secret', () => {
      const s1 = 'jbsw y3dp ehpk 3pxp';
      const s2 = 'JBSWY3DPEHPK3PXP';
      expect(generateTOTP(s1)).toBe(generateTOTP(s2));
    });

    it('should return empty string for missing or invalid secret', () => {
      expect(generateTOTP('')).toBe('');
    });
  });

  describe('Angel One Token Resolution', () => {
    it('should resolve symbol tokens for major Indian equities across NSE and BSE', () => {
      const relToken = AngelOneService.resolveToken('RELIANCE');
      expect(relToken).not.toBeNull();
      expect(relToken?.token).toBe('2885');
      expect(relToken?.exchange).toBe('NSE');
      expect(relToken?.exchType).toBe(1);

      const sbinToken = AngelOneService.resolveToken('SBIN');
      expect(sbinToken?.token).toBe('3045');

      const yesToken = AngelOneService.resolveToken('YESBANK');
      expect(yesToken?.token).toBe('11915');

      const ideaToken = AngelOneService.resolveToken('IDEA');
      expect(ideaToken?.token).toBe('14366');

      const jioToken = AngelOneService.resolveToken('JIOFIN');
      expect(jioToken?.token).toBe('18143');

      const knrToken = AngelOneService.resolveToken('KNRCON');
      expect(knrToken?.token).toBe('14574');
    });

    it('should resolve Indian index tokens correctly', () => {
      const nifty = AngelOneService.resolveToken('NIFTY 50');
      expect(nifty?.token).toBe('26000');
      expect(nifty?.exchange).toBe('NSE');

      const bankNifty = AngelOneService.resolveToken('BANKNIFTY');
      expect(bankNifty?.token).toBe('26009');

      const sensex = AngelOneService.resolveToken('SENSEX');
      expect(sensex?.token).toBe('1');
      expect(sensex?.exchange).toBe('BSE');
    });

    it('should resolve MCX commodity tokens', () => {
      const gold = AngelOneService.resolveToken('GOLD');
      expect(gold?.token).toBe('248740');
      expect(gold?.exchange).toBe('MCX');
      expect(gold?.exchType).toBe(5);

      const crude = AngelOneService.resolveToken('CRUDEOIL');
      expect(crude?.token).toBe('249580');
      expect(crude?.exchange).toBe('MCX');
    });
  });

  describe('Delayed Status Accuracy & Market Hours', () => {
    it('should accurately report delayed flag when broker/finnhub is not connected', () => {
      // Crypto on Binance is always LIVE (delayed = false)
      expect(ChartStreamService.isDelayed('BTC/USDT')).toBe(false);
      expect(ChartStreamService.isDelayed('ETH/USDT')).toBe(false);

      // Without Angel One connected, Indian stocks must be reported as delayed = true
      expect(ChartStreamService.isDelayed('RELIANCE')).toBe(!AngelOneService.isConnected());
      expect(ChartStreamService.isDelayed('SBIN')).toBe(!AngelOneService.isConnected());
      expect(ChartStreamService.isDelayed('YESBANK')).toBe(!AngelOneService.isConnected());
    });

    it('should provide complete exchange market session status without throwing', () => {
      const status = MarketDataService.getMarketStatus();
      expect(status).toBeDefined();
      expect(Array.isArray(status.exchanges)).toBe(true);

      const nse = status.exchanges.find((e) => e.exchange === 'NSE');
      expect(nse).toBeDefined();
      expect(['PRE_OPEN', 'REGULAR', 'POST_CLOSE', 'CLOSED']).toContain(nse?.session);
      expect(typeof nse?.isOpen).toBe('boolean');

      const crypto = status.exchanges.find((e) => e.exchange === 'CRYPTO');
      expect(crypto?.isOpen).toBe(true);
      expect(crypto?.session).toBe('24_7');

      const mcx = status.exchanges.find((e) => e.exchange === 'MCX');
      expect(mcx).toBeDefined();
      expect(['REGULAR', 'CLOSED']).toContain(mcx?.session);
    });
  });

  describe('Viewer-Based Subscription & Cap Guards', () => {
    it('should enforce subscription cap of 500 tokens', () => {
      expect(AngelOneService.SUBSCRIPTION_CAP).toBe(500);
    });

    it('should cleanly handle subscribe and unsubscribe without throwing', () => {
      expect(() => {
        AngelOneService.subscribe('RELIANCE', 'room:test:1');
        AngelOneService.subscribe('RELIANCE', 'room:test:2');
        AngelOneService.unsubscribe('RELIANCE', 'room:test:1');
        AngelOneService.unsubscribe('RELIANCE', 'room:test:2');
      }).not.toThrow();
    });
  });
});
