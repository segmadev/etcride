<?php
$router = new Router();

// ── Public ────────────────────────────────────────────────────────────────────
$router->get('/health',          'health@check');
$router->get('/content/common',        'FrontContent@commonDetails');
$router->get('/content/tcp',           'FrontContent@getTCandPolicy');
$router->get('/content/map-settings',  'FrontContent@mapSettings');
$router->get('/content/vehicle-types',     'FrontContent@vehicleTypes');
$router->get('/content/driver-availability', 'FrontContent@driverAvailability');
$router->get('/content/directions',          'FrontContent@directions');
// Google Maps proxy — keeps API key server-side, avoids browser CORS errors
$router->get('/content/places',        'FrontContent@placesAutocomplete');
$router->get('/content/place-details', 'FrontContent@placeDetails');
$router->get('/content/geocode',       'FrontContent@geocode');

// ── Customer auth (public) ────────────────────────────────────────────────────
$router->post('/auth/register',             'auth@register');
$router->post('/auth/verify-email',         'auth@verifyEmail');
$router->post('/auth/resend-verification',  'auth@resendVerification');
$router->post('/auth/login',                'auth@login');
$router->post('/auth/forgot-password',      'auth@forgotPassword');
$router->post('/auth/reset-password',       'auth@resetPassword');
$router->post('/auth/send-otp',             'auth@sendOtp');
$router->post('/auth/verify-otp',           'auth@verifyOtp');

// ── Customer auth (protected) ─────────────────────────────────────────────────
$router->group('/auth', function ($r) {
    $r->post('/logout',   'auth@logout');
    $r->put('/profile',   'auth@updateProfile');
}, ['auth' => true, 'authType' => 'customer']);

// ── Fare estimation (public) ──────────────────────────────────────────────────
$router->post('/fare/estimate', 'Fare@estimate');

// ── Customer bookings ─────────────────────────────────────────────────────────
$router->group('/bookings', function ($r) {
    $r->post('/',                          'Bookings@create');
    $r->get('/',                           'Bookings@index');
    $r->get('/:id',                        'Bookings@show');
    $r->post('/:id/cancel',                'Bookings@cancelIfNotStarted');
    $r->get('/:id/track',                  'Bookings@track');
    $r->post('/:id/confirm-delivery',      'Bookings@confirmDelivery');
    $r->post('/:id/pay',                   'Payments@initiate');
    $r->get('/:id/payment-status',         'Payments@status');
    $r->put('/:id/payment-method',         'Bookings@updatePaymentMethod');
    $r->post('/:id/rate',                  'Bookings@rateDriver');
}, ['auth' => true, 'authType' => 'customer']);

// ── Customer notifications ────────────────────────────────────────────────────
$router->group('/notifications', function ($r) {
    $r->get('/',          'Bookings@notifications');
    $r->put('/:id/read',  'Bookings@markNotificationRead');
    $r->put('/read-all',  'Bookings@markAllNotificationsRead');
}, ['auth' => true, 'authType' => 'customer']);

// ── Payment webhooks (public — verified via provider signature) ───────────────
$router->post('/payments/webhook/flutterwave', 'payments/Webhook@flutterwave');
$router->post('/payments/webhook/monnify',     'payments/Webhook@monnify');

// ── Driver auth (public) ──────────────────────────────────────────────────────
$router->post('/driver/auth/login', 'driver/Auth@login');

// ── Driver protected routes ───────────────────────────────────────────────────
$router->group('/driver', function ($r) {

    // Auth
    $r->post('/auth/logout',           'driver/Auth@logout');
    $r->put('/auth/profile',           'driver/Auth@updateProfile');

    // Availability
    $r->put('/availability',           'driver/Availability@toggle');

    // Location ping
    $r->post('/location',              'driver/Location@ping');

    // Jobs
    $r->get('/jobs',                   'driver/Jobs@index');
    $r->get('/jobs/:id',               'driver/Jobs@show');
    $r->post('/jobs/:id/accept',       'driver/Jobs@accept');
    $r->post('/jobs/:id/reject',       'driver/Jobs@reject');
    $r->post('/jobs/:id/arrive',       'driver/Jobs@arrive');
    $r->post('/jobs/:id/start',        'driver/Jobs@start');
    $r->post('/jobs/:id/complete',     'driver/Jobs@complete');
    $r->put('/jobs/:id/payment-method','driver/Jobs@updatePaymentMethod');
    $r->post('/jobs/:id/stops/:stop_id/reach', 'driver/Jobs@reachStop');

    // History
    $r->get('/history',                'driver/Jobs@history');

    // Notifications
    $r->get('/notifications',              'driver/Jobs@notifications');
    $r->put('/notifications/:id/read',     'driver/Jobs@markNotificationRead');

}, ['auth' => true, 'authType' => 'driver']);
