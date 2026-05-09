import { apiClient, apiRequest } from './client';
import type { AdminUser } from '../types';

export const profileApi = {
  get: () =>
    apiRequest<AdminUser>(apiClient.get('/admin/profile')),

  update: (payload: { name?: string; email?: string }) =>
    apiRequest<AdminUser>(apiClient.put('/admin/profile', payload)),

  changePassword: (payload: { current_password: string; new_password: string }) =>
    apiRequest<null>(apiClient.put('/admin/profile/password', payload)),
};
