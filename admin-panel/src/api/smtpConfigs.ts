import { apiClient, apiRequest } from './client';

export interface SmtpConfig {
  id: number;
  name: string;
  host: string;
  port: number;
  username: string;
  encryption: 'tls' | 'ssl' | 'none';
  from_name: string;
  from_email: string;
  is_active: boolean | number;
  has_password: boolean;
  created_at: string;
}

export interface SmtpConfigPayload {
  name: string;
  host: string;
  port: number;
  username: string;
  password?: string;
  encryption: 'tls' | 'ssl' | 'none';
  from_name: string;
  from_email: string;
}

export const smtpConfigsApi = {
  list: () =>
    apiRequest<SmtpConfig[]>(apiClient.get('/admin/smtp-configs')),

  create: (payload: SmtpConfigPayload) =>
    apiRequest<{ id: number }>(apiClient.post('/admin/smtp-configs', payload)),

  update: (id: number, payload: Partial<SmtpConfigPayload>) =>
    apiRequest<void>(apiClient.put(`/admin/smtp-configs/${id}`, payload)),

  activate: (id: number) =>
    apiRequest<void>(apiClient.put(`/admin/smtp-configs/${id}/activate`, {})),

  remove: (id: number) =>
    apiRequest<void>(apiClient.delete(`/admin/smtp-configs/${id}`)),

  test: (to: string, smtpConfigId?: number) =>
    apiRequest<void>(apiClient.post('/admin/smtp-configs/test', {
      to,
      ...(smtpConfigId ? { smtp_config_id: smtpConfigId } : {}),
    })),
};
