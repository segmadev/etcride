<?php
require_once ROOT . 'functions/BaseController.php';

class Fare extends BaseController
{
    // ── POST /fare/estimate ───────────────────────────────────────────────────
    // Public endpoint — no auth required (used before booking is created)
    public function estimate(): void
    {
        $err = $this->requireFields(['pickup_lat', 'pickup_lng', 'destination_lat', 'destination_lng', 'vehicle_type_id']);
        if ($err) { echo $err; return; }

        $pickupLat   = $this->flt('pickup_lat');
        $pickupLng   = $this->flt('pickup_lng');
        $destLat     = $this->flt('destination_lat');
        $destLng     = $this->flt('destination_lng');
        $vtId        = $this->str('vehicle_type_id');
        $bookingType = $this->str('booking_type', 'ride');

        // Validate vehicle type exists
        $vt = $this->getall('vehicle_types', 'id = ? AND is_active = 1', [$vtId]);
        if (!is_array($vt)) {
            echo utilities::apiMessage('Invalid or inactive vehicle type.', 400);
            return;
        }

        // Parse optional stops
        $stopsRaw = $_POST['stops'] ?? [];
        if (is_string($stopsRaw)) {
            $stopsRaw = json_decode($stopsRaw, true) ?? [];
        }
        $stops = is_array($stopsRaw) ? $stopsRaw : [];
        $numStops = count($stops);

        // Calculate distance
        $calcMethod = $this->setting('calc_method', 'server');
        $distanceKm = 0.0;

        if ($calcMethod === 'app' && isset($_POST['distance_km'])) {
            $distanceKm = (float) $_POST['distance_km'];
        } else {
            // Server-side Haversine — accumulate across all waypoints
            $allPoints = array_merge(
                [['lat' => $pickupLat, 'lng' => $pickupLng]],
                array_map(fn($s) => ['lat' => (float)($s['lat'] ?? 0), 'lng' => (float)($s['lng'] ?? 0)], $stops),
                [['lat' => $destLat, 'lng' => $destLng]]
            );
            for ($i = 0; $i < count($allPoints) - 1; $i++) {
                $distanceKm += $this->haversine(
                    $allPoints[$i]['lat'], $allPoints[$i]['lng'],
                    $allPoints[$i + 1]['lat'], $allPoints[$i + 1]['lng']
                );
            }
            $distanceKm = round($distanceKm, 2);
        }

        // Get zone (default for now — customer location matching TBD)
        $zoneId = $this->getDefaultZoneId();

        $fare = $this->calculateFare($vtId, $zoneId, $distanceKm, $numStops, null, $bookingType);

        // Fetch pricing breakdown for transparency
        $pricing = null;
        if ($zoneId) {
            $pricing = $this->getall('zone_pricing',
                'zone_id = ? AND vehicle_type_id = ? AND is_active = 1', [$zoneId, $vtId]);
        }
        if (!is_array($pricing)) {
            $pricing = $vt;
        }

        $timeFareEnabled = $this->setting('time_fare_enabled', '0') === '1';
        $perMinuteRate   = (float) $this->setting('time_fare_per_minute', '5');

        echo utilities::apiMessage('Fare estimated.', 200, [
            'vehicle_type'   => ['id' => $vt['id'], 'name' => $vt['name']],
            'distance_km'    => $distanceKm,
            'num_stops'      => $numStops,
            'estimated_fare' => $fare,
            'currency'       => $this->setting('currency', 'NGN'),
            'breakdown'      => [
                'base_fare'         => (float) $pricing['base_fare'],
                'per_km_rate'       => (float) $pricing['per_km_rate'],
                'per_stop_fee'      => (float) $pricing['per_stop_fee'],
                'time_fare_enabled' => $timeFareEnabled,
                'per_minute_rate'   => $timeFareEnabled ? $perMinuteRate : 0,
            ],
        ]);
    }
}
