import axios, { AxiosError } from 'axios';

const BASE_URL = import.meta.env.VITE_API_URL ?? 'http://localhost/etcride/api';

export const apiClient = axios.create({
  baseURL: BASE_URL,
  headers: { 'Content-Type': 'application/json' },
  timeout: 15_000,
});

// ── Request: attach Bearer token ──────────────────────────────────────────
apiClient.interceptors.request.use(config => {
  const token = localStorage.getItem('etcride_admin_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// ── Response: handle 401 ──────────────────────────────────────────────────
apiClient.interceptors.response.use(
  res => res,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('etcride_admin_token');
      localStorage.removeItem('etcride_admin_user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  },
);

// ── ApiError ──────────────────────────────────────────────────────────────
export interface ApiError extends Error {
  code: number;
  errors: Record<string, string[]> | null;
}

function makeApiError(message: string, code: number, errors: Record<string, string[]> | null = null): ApiError {
  const err = new Error(message) as ApiError;
  err.code = code;
  err.errors = errors;
  return err;
}

/** Returns a UI-ready string from any thrown value, including field-level validation errors. */
export function getApiErrorMessage(error: unknown): string {
  if (!error || typeof error !== 'object') return 'An unexpected error occurred.';
  const e = error as Partial<ApiError>;
  const msg = e.message || 'An unexpected error occurred.';
  if (e.errors && Object.keys(e.errors).length > 0) {
    const lines = Object.entries(e.errors).map(([field, msgs]) => `• ${field}: ${msgs.join(', ')}`);
    return `${msg}\n${lines.join('\n')}`;
  }
  return msg;
}

type Envelope<T> = { code: number; message: string; data: T; errors: Record<string, string[]> | null };

/** Unwrap the API response envelope; on any error throw ApiError with the server's message. */
export async function apiRequest<T>(
  promise: Promise<{ data: Envelope<T> }>,
): Promise<T> {
  try {
    const res = await promise;
    const body = res.data;
    if (body.code >= 400) {
      throw makeApiError(body.message, body.code, body.errors);
    }
    return body.data;
  } catch (raw) {
    // Already our ApiError — re-throw unchanged
    if (raw instanceof Error && 'code' in raw && 'errors' in raw) throw raw;

    if (raw instanceof AxiosError) {
      // Server responded with 4xx/5xx — use the JSON body message
      if (raw.response?.data) {
        const body = raw.response.data as Partial<Envelope<T>>;
        throw makeApiError(
          body.message ?? raw.message,
          body.code ?? raw.response.status,
          body.errors ?? null,
        );
      }
      // Network / timeout
      const msg = raw.code === 'ECONNABORTED'
        ? 'Request timed out. Please try again.'
        : 'Network error. Check your connection.';
      throw makeApiError(msg, 0);
    }

    throw raw;
  }
}
