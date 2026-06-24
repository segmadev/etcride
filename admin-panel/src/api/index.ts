export { apiClient, getApiErrorMessage } from './client';
export type { ApiError } from './client';
export { authApi } from './auth';
export { bookingsApi } from './bookings';
export { driversApi } from './drivers';
export { vehiclesApi } from './vehicles';
export { vehicleTypesApi } from './vehicleTypes';
export { zonesApi } from './zones';
export { settingsApi } from './settings';
export { reportsApi } from './reports';
export { mapSettingsApi } from './mapSettings';
export { emailTemplatesApi } from './emailTemplates';
export { paymentsApi } from './payments';
export type { Payment, PaymentsFilter } from './payments';
export { smtpConfigsApi } from './smtpConfigs';
export type { SmtpConfig, SmtpConfigPayload } from './smtpConfigs';

// Trip Reports API
export { tripReportsApi } from './tripReports';
export type { TripReport, TripReportDetail } from './tripReports';
