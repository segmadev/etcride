import { apiClient, apiRequest } from './client';
import type { Settings } from '../types';

export const settingsApi = {
  list: () =>
    apiRequest<Settings>(apiClient.get('/admin/settings')),

  update: (payload: Record<string, string>) =>
    apiRequest<{ updated: string[]; ignored: string[] }>(
      apiClient.put('/admin/settings', payload),
    ),
};
