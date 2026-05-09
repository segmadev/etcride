import axios, { AxiosError } from 'axios';

// Point this at your PHP API base URL.
// In development use the .env var; in production set VITE_API_URL at build time.
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

// ── Response: unwrap envelope / handle 401 ────────────────────────────────
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

/** Extract .data from the response envelope or throw with the API message */
export async function apiRequest<T>(
  promise: Promise<{ data: { code: number; message: string; data: T; errors: unknown } }>,
): Promise<T> {
  const res = await promise;
  const body = res.data;
  if (body.code >= 400) {
    const err = new Error(body.message) as Error & { code: number };
    err.code = body.code;
    throw err;
  }
  return body.data;
}
