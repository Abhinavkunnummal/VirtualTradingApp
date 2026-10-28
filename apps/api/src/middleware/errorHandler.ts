import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';

export function errorHandler(
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
) {
  const isProduction = process.env.NODE_ENV === 'production';

  // Log error safely without exposing raw auth headers or credentials
  if (!isProduction) {
    console.error('[API Error]', err?.message || err);
  }

  if (err instanceof ZodError) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: err.errors.map(e => ({ path: e.path.join('.'), message: e.message }))
    });
  }

  const statusCode = err.statusCode || (err.status && typeof err.status === 'number' ? err.status : 500);
  const message = (isProduction && statusCode === 500)
    ? 'An unexpected internal server error occurred.'
    : (err.message || 'Internal Server Error');

  return res.status(statusCode).json({
    success: false,
    message,
    ...(!isProduction && { stack: err.stack })
  });
}
