<?php
require_once ROOT . 'functions/BaseController.php';

class Location extends BaseController
{
    // ── POST /driver/location ─────────────────────────────────────────────────
    // Driver pings current coordinates (called every N seconds during trip)
    public function ping(): void
    {
        $me  = BaseController::$authDriver;
        $err = $this->requireFields(['lat', 'lng']);
        if ($err) { echo $err; return; }

        $lat     = $this->flt('lat');
        $lng     = $this->flt('lng');
        $tripId  = $this->str('trip_id') ?: null;
        $now     = date('Y-m-d H:i:s');

        // Update driver's last known position
        $this->update('drivers', [
            'last_lat'  => $lat,
            'last_lng'  => $lng,
            'last_seen' => $now,
        ], "id = '{$me['id']}'");

        // Append to location log
        $this->quick_insert('driver_location_logs', [
            'driver_id'   => $me['id'],
            'trip_id'     => $tripId,
            'lat'         => $lat,
            'lng'         => $lng,
            'recorded_at' => $now,
        ]);

        echo utilities::apiMessage('Location updated.', 200, [
            'lat'       => $lat,
            'lng'       => $lng,
            'recorded'  => $now,
        ]);
    }
}
