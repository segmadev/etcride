<?php
$router = new Router();

// ── Public ────────────────────────────────────────────────────────────────────
$router->get('/health',          'health@check');
$router->get('/content/common',        'FrontContent@commonDetails');
$router->get('/content/tcp',           'FrontContent@getTCandPolicy');
$router->get('/content/map-settings',  'FrontContent@mapSettings');
$router->get('/content/vehicle-types',      'FrontContent@vehicleTypes');
$router->get('/content/delivery-rules',    'FrontContent@deliveryRules');
$router->get('/content/driver-availability', 'FrontContent@driverAvailability');
$router->get('/content/directions',          'FrontContent@directions');
// Google Maps proxy — keeps API key server-side, avoids browser CORS errors
$router->get('/content/places',        'FrontContent@placesAutocomplete');
$router->get('/content/place-details', 'FrontContent@placeDetails');
$router->get('/content/geocode',       'FrontContent@geocode');
$router->get('/content/driver-auth-config', 'FrontContent@driverAuthConfig');
$router->get('/content/driver-locations',   'FrontContent@driverLocations');
// Serves uploaded files (vehicle/driver photos, KYC images) through PHP so CORS
// headers are always applied — direct /uploads/* static serving bypasses PHP
// entirely on some servers (e.g. `php -S`), so .htaccess-based CORS never runs.
// Filename is passed as ?file= (not a path segment) because PHP's built-in dev
// server short-circuits any URL path ending in a recognized extension (.webp,
// .jpg, etc.) straight to its own static handler — it never reaches PHP at all,
// even if no such file exists on disk. An extensionless path always falls
// through to index.php as expected.
$router->get('/files/:folder', 'FrontContent@serveUpload');

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
    $r->post('/:id/find-driver',           'Bookings@findDriver');
    $r->get('/:id/track',                  'Bookings@track');
    $r->post('/:id/confirm-delivery',      'Bookings@confirmDelivery');
    $r->post('/:id/pay',                   'Payments@initiate');
    $r->get('/:id/payment-status',         'Payments@status');
    $r->put('/:id/payment-method',         'Bookings@updatePaymentMethod');
    $r->post('/:id/rate',                  'Bookings@rateDriver');
    $r->get('/:id/messages',                'Bookings@getMessages');
    $r->post('/:id/messages',               'Bookings@sendMessage');
}, ['auth' => true, 'authType' => 'customer']);

$router->get('/chats', 'Bookings@chatThreads', true);
$router->post('/chats/:id/read', 'Bookings@markChatRead', true);

// ── Customer notifications ────────────────────────────────────────────────────
$router->group('/notifications', function ($r) {
    $r->get('/',          'Bookings@notifications');
    $r->put('/:id/read',  'Bookings@markNotificationRead');
    $r->put('/read-all',  'Bookings@markAllNotificationsRead');
}, ['auth' => true, 'authType' => 'customer']);

// ── Payment webhooks (public — verified via provider signature) ───────────────
$router->post('/payments/webhook/flutterwave', 'payments/Webhook@flutterwave');
$router->post('/payments/webhook/monnify',     'payments/Webhook@monnify');
// After Flutterwave checkout, user is redirected here → returns HTML that closes/redirects
$router->get('/payments/callback', 'payments/Webhook@callback');

// ── Driver auth (public) ──────────────────────────────────────────────────────
$router->post('/driver/auth/login', 'driver/Auth@login');
$router->post('/driver/auth/register',   'driver/Auth@register');
$router->post('/driver/auth/send-otp',   'driver/Auth@sendOtp');
$router->post('/driver/auth/verify-otp', 'driver/Auth@verifyOtp');

// ── Driver protected routes ───────────────────────────────────────────────────
$router->group('/driver', function ($r) {

    // Auth
    $r->post('/auth/logout',           'driver/Auth@logout');
    $r->get('/auth/profile',           'driver/Auth@getProfile');
    $r->put('/auth/profile',           'driver/Auth@updateProfile');

    // Availability
    $r->put('/availability',           'driver/Availability@toggle');

    // Location ping
    $r->post('/location',              'driver/Location@ping');

    $r->post('/kyc',                   'driver/Kyc@submit');

    // Jobs
    $r->get('/jobs',                   'driver/Jobs@index');
    $r->get('/jobs/:id',               'driver/Jobs@show');
    $r->post('/jobs/:id/accept',       'driver/Jobs@accept');
    $r->post('/jobs/:id/reject',       'driver/Jobs@reject');
    $r->post('/jobs/:id/cancel',       'driver/Jobs@cancel');
    $r->post('/jobs/:id/arrive',       'driver/Jobs@arrive');
    $r->post('/jobs/:id/confirm-pickup-payment', 'driver/Jobs@confirmPickupPayment');
    $r->post('/jobs/:id/pickup',       'driver/Jobs@pickup');
    $r->post('/jobs/:id/start',        'driver/Jobs@start');
    $r->post('/jobs/:id/complete',          'driver/Jobs@complete');
    $r->post('/jobs/:id/confirm-payment',   'driver/Jobs@confirmPayment');
    $r->put('/jobs/:id/payment-method',     'driver/Jobs@updatePaymentMethod');
    $r->post('/jobs/:id/stops/:stop_id/reach', 'driver/Jobs@reachStop');
    $r->get('/jobs/:id/messages',              'driver/Jobs@getMessages');
    $r->post('/jobs/:id/messages',             'driver/Jobs@sendMessage');
    $r->get('/chats',                          'driver/Jobs@chatThreads');
    $r->post('/chats/:id/read',                'driver/Jobs@markChatRead');

    // History
    $r->get('/history',                'driver/Jobs@history');

    // Notifications
    $r->get('/notifications',              'driver/Jobs@notifications');
    $r->put('/notifications/:id/read',     'driver/Jobs@markNotificationRead');

}, ['auth' => true, 'authType' => 'driver']);
