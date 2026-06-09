<?php
require_once ROOT . 'functions/BaseController.php';

class FrontContent extends BaseController
{
    public function driverAuthConfig(): void
    {
        $mode = strtolower(trim($this->setting('driver_auth_mode', 'both')));
        if (!in_array($mode, ['otp', 'password', 'both'], true)) $mode = 'both';
        echo utilities::apiMessage('Driver auth config retrieved.', 200, [
            'mode' => $mode,
        ]);
    }

    public function driverLocations(): void
    {
        $raw = trim($this->setting('driver_locations_json', ''));
        if ($raw === '') {
            echo utilities::apiMessage('Driver locations retrieved.', 200, ['states' => []]);
            return;
        }
        $decoded = json_decode($raw, true);
        echo utilities::apiMessage('Driver locations retrieved.', 200, [
            'states' => is_array($decoded) ? $decoded : [],
        ]);
    }

    public function commonDetails(): void
    {
        echo utilities::apiMessage('Common details retrieved.', 200, [
            'app_name'        => $this->setting('app_name',        'EtcRide'),
            'app_tagline'     => $this->setting('app_tagline',     ''),
            'about_text'      => $this->setting('about_text',      ''),
            'support_email'   => $this->setting('support_email',   ''),
            'support_phone'   => $this->setting('support_phone',   ''),
            'currency'        => $this->setting('currency',        'NGN'),
            'currency_symbol'       => $this->setting('currency_symbol', '₦'),
            'auto_arrive_radius_m'   => (int)   $this->setting('auto_arrive_radius_m',   '20'),
            'driver_avg_speed_kmh'   => (int)   $this->setting('driver_avg_speed_kmh',   '30'),
            'free_waiting_minutes'   => (int)   $this->setting('free_waiting_minutes',   '3'),
            'waiting_charge_per_min' => (float) $this->setting('waiting_charge_per_min', '0'),
        ]);
    }

    public function getTCandPolicy(): void
    {
        echo utilities::apiMessage('Terms and policy retrieved.', 200, [
            'terms'  => $this->setting('terms_and_conditions', ''),
            'policy' => $this->setting('privacy_policy',       ''),
        ]);
    }

    public function mapSettings(): void
    {
        $boundary = $this->setting('service_boundary', '[]');
        $webKey = $this->setting('google_maps_web_key', '');
        if ($webKey === '') $webKey = $this->setting('google_maps_api_key', '');
        echo utilities::apiMessage('Map settings retrieved.', 200, [
            'api_key'     => $webKey,
            'center'      => [
                'lat' => (float) $this->setting('map_center_lat', '8.4966'),
                'lng' => (float) $this->setting('map_center_lng', '4.5421'),
            ],
            'zoom'        => (int) $this->setting('map_default_zoom', '12'),
            'boundary'    => json_decode($boundary, true) ?? [],
            'enforcement' => $this->setting('booking_boundary_enforcement', '0') === '1',
        ]);
    }

    // ── Google Maps proxy endpoints ────────────────────────────────────────────
    // All Google API calls are made server-side so:
    //   1. The API key is never sent to the browser.
    //   2. There are no CORS errors (server-to-server request).
    // Uses the legacy Places API (maps.googleapis.com) — requires "Places API" enabled.

    public function placesAutocomplete(): void
    {
        $input = trim($this->query('input', ''));
        if ($input === '') {
            echo utilities::apiMessage('input is required.', 422);
            return;
        }
        $apiKey       = $this->setting('google_maps_server_key', '');
        if ($apiKey === '') $apiKey = $this->setting('google_maps_api_key', '');
        if ($apiKey === '') {
            echo utilities::apiMessage('Google Maps server API key is not configured.', 503);
            return;
        }
        $sessionToken = $this->query('sessiontoken', '');
        $centerLat    = $this->setting('map_center_lat', '8.4966');
        $centerLng    = $this->setting('map_center_lng', '4.5421');

        $params = [
            'key'      => $apiKey,
            'input'    => $input,
            'location' => $centerLat . ',' . $centerLng,
            'radius'   => 50000,
        ];
        if ($sessionToken !== '') $params['sessiontoken'] = $sessionToken;

        [$data, $err] = $this->googleGet(
            'https://maps.googleapis.com/maps/api/place/autocomplete/json',
            $params
        );

        if ($err !== null) {
            echo utilities::apiMessage('Places API unreachable: ' . $err, 502);
            return;
        }
        if (($data['status'] ?? '') !== 'OK' && ($data['status'] ?? '') !== 'ZERO_RESULTS') {
            $msg = $data['error_message'] ?? ($data['status'] ?? 'Places API error');
            echo utilities::apiMessage($msg, 502);
            return;
        }

        // Legacy response already has the shape MapsService.dart expects.
        echo utilities::apiMessage('OK', 200, [
            'predictions' => $data['predictions'] ?? [],
            'status'      => $data['status']      ?? 'OK',
        ]);
    }

    public function placeDetails(): void
    {
        $placeId = trim($this->query('place_id', ''));
        if ($placeId === '') {
            echo utilities::apiMessage('place_id is required.', 422);
            return;
        }
        $apiKey = $this->setting('google_maps_server_key', '');
        if ($apiKey === '') $apiKey = $this->setting('google_maps_api_key', '');
        if ($apiKey === '') {
            echo utilities::apiMessage('Google Maps server API key is not configured.', 503);
            return;
        }

        [$data, $err] = $this->googleGet(
            'https://maps.googleapis.com/maps/api/place/details/json',
            [
                'key'      => $apiKey,
                'place_id' => $placeId,
                'fields'   => 'geometry/location',
            ]
        );

        if ($err !== null) {
            echo utilities::apiMessage('Places API unreachable: ' . $err, 502);
            return;
        }
        if (($data['status'] ?? '') !== 'OK') {
            $msg = $data['error_message'] ?? ($data['status'] ?? 'Place not found');
            echo utilities::apiMessage($msg, ($data['status'] === 'NOT_FOUND' ? 404 : 502));
            return;
        }

        // Pass through — shape already matches what MapsService.dart expects:
        // { result: { geometry: { location: { lat, lng } } }, status: 'OK' }
        echo utilities::apiMessage('OK', 200, [
            'result' => $data['result'] ?? null,
            'status' => $data['status'] ?? 'OK',
        ]);
    }

    public function geocode(): void
    {
        $address = trim($this->query('address', ''));
        $latlng  = trim($this->query('latlng',  ''));

        if ($address === '' && $latlng === '') {
            echo utilities::apiMessage('address or latlng is required.', 422);
            return;
        }
        $apiKey = $this->setting('google_maps_server_key', '');
        if ($apiKey === '') $apiKey = $this->setting('google_maps_api_key', '');
        if ($apiKey === '') {
            echo utilities::apiMessage('Google Maps server API key is not configured.', 503);
            return;
        }

        // Geocoding API has no "New" version yet; standard endpoint still works.
        $params = ['key' => $apiKey];
        if ($address !== '') $params['address'] = $address;
        if ($latlng  !== '') $params['latlng']  = $latlng;

        [$data, $err] = $this->googleGet(
            'https://maps.googleapis.com/maps/api/geocode/json',
            $params
        );

        if ($err !== null) {
            echo utilities::apiMessage('Geocoding API unreachable: ' . $err, 502);
            return;
        }
        $status = $data['status'] ?? '';
        if ($status !== 'OK' && $status !== 'ZERO_RESULTS') {
            $msg = $data['error_message'] ?? ($status !== '' ? $status : 'Geocoding API error');
            echo utilities::apiMessage($msg, 502, $data);
            return;
        }

        echo utilities::apiMessage('OK', 200, $data);
    }

    /**
     * GET to legacy Google Maps REST API (uses ?key= query param).
     * Returns [$responseArray, $errorString|null].
     */
    private function googleGet(string $url, array $params): array
    {
        $ch = curl_init($url . '?' . http_build_query($params));
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_HTTPHEADER     => ['Accept: application/json'],
            CURLOPT_SSL_VERIFYPEER => true,
        ]);
        $resp = curl_exec($ch);
        $err  = $resp === false ? curl_error($ch) : null;
        curl_close($ch);
        return $resp !== false ? [json_decode($resp, true) ?? [], null] : [[], $err];
    }

    /**
     * GET to Places API (New) — key in X-Goog-Api-Key header, fields in X-Goog-FieldMask.
     * Returns [$responseArray, $errorString|null].
     */
    private function googleGetNew(string $url, string $apiKey, string $fieldMask = ''): array
    {
        $headers = ['Accept: application/json', 'X-Goog-Api-Key: ' . $apiKey];
        if ($fieldMask !== '') $headers[] = 'X-Goog-FieldMask: ' . $fieldMask;

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_HTTPHEADER     => $headers,
            CURLOPT_SSL_VERIFYPEER => true,
        ]);
        $resp = curl_exec($ch);
        $err  = $resp === false ? curl_error($ch) : null;
        curl_close($ch);
        return $resp !== false ? [json_decode($resp, true) ?? [], null] : [[], $err];
    }

    /**
     * POST to Places API (New) — key in X-Goog-Api-Key header.
     * Returns [$responseArray, $errorString|null].
     */
    private function googlePostNew(string $url, array $body, string $apiKey, string $fieldMask = ''): array
    {
        $headers = [
            'Content-Type: application/json',
            'Accept: application/json',
            'X-Goog-Api-Key: ' . $apiKey,
        ];
        if ($fieldMask !== '') $headers[] = 'X-Goog-FieldMask: ' . $fieldMask;

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 10,
            CURLOPT_HTTPHEADER     => $headers,
            CURLOPT_POSTFIELDS     => json_encode($body),
            CURLOPT_SSL_VERIFYPEER => true,
        ]);
        $resp = curl_exec($ch);
        $err  = $resp === false ? curl_error($ch) : null;
        curl_close($ch);
        return $resp !== false ? [json_decode($resp, true) ?? [], null] : [[], $err];
    }

    public function vehicleTypes(): void
    {
        $type = $this->query('type', ''); // 'ride' | 'delivery' | ''

        $where  = $type !== '' ? "is_active = 1 AND category = ?" : "is_active = 1";
        $params = $type !== '' ? [$type] : [];

        $stmt = $this->db->prepare(
            "SELECT id, name, COALESCE(category, 'ride') as category,
                    base_fare, per_km_rate, per_stop_fee,
                    description, icon, sort_order
             FROM vehicle_types
             WHERE $where
             ORDER BY COALESCE(sort_order, 99), name ASC"
        );
        $stmt->execute($params);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Enrich with zone pricing from default zone (if available)
        $zoneId = $this->getDefaultZoneId();
        if ($zoneId) {
            foreach ($rows as &$vt) {
                $pricing = $this->getall('zone_pricing',
                    'zone_id = ? AND vehicle_type_id = ? AND is_active = 1',
                    [$zoneId, $vt['id']]);
                if (is_array($pricing)) {
                    $vt['base_fare']    = $pricing['base_fare'];
                    $vt['per_km_rate']  = $pricing['per_km_rate'];
                    $vt['per_stop_fee'] = $pricing['per_stop_fee'];
                }
            }
            unset($vt);
        }

        echo utilities::apiMessage('Vehicle types retrieved.', 200, $rows);
    }
}
