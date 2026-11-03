import { config } from '../../config';

/**
 * Shared Budget Guard to prevent exhausting Alpha Vantage free tier limits.
 * Default: 5 requests per minute, 25 requests per day.
 * Configurable via ALPHA_VANTAGE_RPM and ALPHA_VANTAGE_RPD env variables.
 */
export class RateLimitBudgetGuard {
  private maxPerMinute: number;
  private maxPerDay: number;
  private requestTimestamps: number[] = [];
  private dayCount: number = 0;
  private currentDay: string = '';

  constructor(
    maxPerMinute = config.alphaVantageRpm,
    maxPerDay = config.alphaVantageRpd
  ) {
    this.maxPerMinute = maxPerMinute;
    this.maxPerDay = maxPerDay;
    this.currentDay = new Date().toISOString().slice(0, 10);
  }

  public setLimits(maxPerMinute: number, maxPerDay: number): void {
    this.maxPerMinute = maxPerMinute;
    this.maxPerDay = maxPerDay;
  }

  public getLimits(): { maxPerMinute: number; maxPerDay: number } {
    return { maxPerMinute: this.maxPerMinute, maxPerDay: this.maxPerDay };
  }

  public canRequest(now = Date.now()): boolean {
    this.pruneOld(now);
    if (this.requestTimestamps.length >= this.maxPerMinute) {
      return false;
    }
    if (this.dayCount >= this.maxPerDay) {
      return false;
    }
    return true;
  }

  public recordRequest(now = Date.now()): boolean {
    if (!this.canRequest(now)) {
      return false;
    }
    this.requestTimestamps.push(now);
    this.dayCount++;
    return true;
  }

  public getStatus(now = Date.now()): {
    minuteUsed: number;
    maxPerMinute: number;
    dayUsed: number;
    maxPerDay: number;
    isBudgetExhausted: boolean;
  } {
    this.pruneOld(now);
    return {
      minuteUsed: this.requestTimestamps.length,
      maxPerMinute: this.maxPerMinute,
      dayUsed: this.dayCount,
      maxPerDay: this.maxPerDay,
      isBudgetExhausted: !this.canRequest(now),
    };
  }

  public reset(): void {
    this.requestTimestamps = [];
    this.dayCount = 0;
    this.currentDay = new Date().toISOString().slice(0, 10);
    this.maxPerMinute = config.alphaVantageRpm;
    this.maxPerDay = config.alphaVantageRpd;
  }

  private pruneOld(now: number): void {
    const today = new Date(now).toISOString().slice(0, 10);
    if (today !== this.currentDay) {
      this.currentDay = today;
      this.dayCount = 0;
    }
    this.requestTimestamps = this.requestTimestamps.filter((t) => now - t < 60000);
  }
}

/**
 * Singleton instance shared across AlphaVantageService and ChartStreamService.
 * All callers draw from this exact same budget counter.
 */
export const sharedAlphaVantageBudget = new RateLimitBudgetGuard();
