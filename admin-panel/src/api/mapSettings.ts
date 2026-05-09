import { apiClient, apiRequest } from './client';

export interface MapSettingsPayload {
  google_maps_api_key?: string;
  google_maps_web_key?: string;
  google_maps_server_key?: string;
  map_center_lat?: string;
  map_center_lng?: string;
  map_default_zoom?: string;
  service_boundary?: string;        // JSON string of LatLng[]
  booking_boundary_enforcement?: string; // '0' | '1'
}

export const mapSettingsApi = {
  /** Fetch settings and flatten { key: { value, ... } } → { key: value } */
  get: async (): Promise<Record<string, string>> => {
    const raw = await apiRequest<Record<string, { value: string }>>(
      apiClient.get('/admin/settings'),
    );
    return Object.fromEntries(Object.entries(raw).map(([k, v]) => [k, v.value]));
  },

  /** Persist map-related keys via the generic settings update */
  save: (payload: MapSettingsPayload) =>
    apiRequest<null>(apiClient.put('/admin/settings', payload)),
};
