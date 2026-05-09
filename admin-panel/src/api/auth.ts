import { apiClient, apiRequest } from './client';
import type { AdminUser } from '../types';

interface LoginPayload { email: string; password: string }
// PHP returns the flat admin row with token injected into it
type LoginResponse = AdminUser & { token: string };

export const authApi = {
  login: (payload: LoginPayload) =>
    apiRequest<LoginResponse>(
      apiClient.post('/admin/auth/login', {
        email: payload.email,
        password: btoa(payload.password),
      }),
    ),

  ping: () =>
    apiRequest<{ admin: AdminUser }>(apiClient.get('/admin/ping')),
};
