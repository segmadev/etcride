import { apiClient, apiRequest } from './client';

export interface EmailTemplate {
  key: string;
  label: string;
  description: string;
  variables: string[];
  subject: string;
  body: string;
}

export const emailTemplatesApi = {
  list: (): Promise<EmailTemplate[]> =>
    apiRequest(apiClient.get('/admin/email-templates')),

  /** Send a test email rendered from the given template key */
  test: (to: string, templateKey: string): Promise<{ message: string }> =>
    apiRequest(apiClient.post('/admin/email-templates/test', { to, template_key: templateKey })),
};
