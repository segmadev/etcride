<?php

// ── Admin routes ──────────────────────────────────────────────────────────────
// All routes under /admin (except login) require Bearer token auth (authType=admin).

// ── Admin auth (public) ───────────────────────────────────────────────────────
$router->post('/admin/auth/login', 'admin/admin@login');

// ── All other admin routes (protected) ───────────────────────────────────────
$router->group('/admin', function ($r) {

    // Ping / health
    $r->get('/ping', 'admin/admin@ping');

    // ── Admin profile ─────────────────────────────────────────────────────────
    $r->get('/profile',          'admin/admin@getProfile');
    $r->put('/profile',          'admin/admin@updateProfile');
    $r->put('/profile/password', 'admin/admin@changePassword');

    // ── Bookings ──────────────────────────────────────────────────────────────
    $r->get('/bookings',                     'admin/Bookings@index');
    $r->get('/bookings/notifications',       'admin/Bookings@notifications');
    $r->get('/bookings/:id',                 'admin/Bookings@show');
    $r->post('/bookings/:id/assign',         'admin/Bookings@assign');
    $r->post('/bookings/:id/reassign',       'admin/Bookings@reassign');
    $r->post('/bookings/:id/deassign',       'admin/Bookings@deassign');
    $r->post('/bookings/:id/cancel',         'admin/Bookings@cancel');
    $r->get('/bookings/:id/track',           'admin/Bookings@track');
    $r->get('/bookings/:id/suggest-drivers', 'admin/Bookings@suggestDrivers');

    // ── Drivers ───────────────────────────────────────────────────────────────
    $r->get('/drivers',                      'admin/Drivers@index');
    $r->post('/drivers',                     'admin/Drivers@create');
    $r->get('/drivers/:id',                  'admin/Drivers@show');
    $r->post('/drivers/:id',                 'admin/Drivers@edit');       // multipart — POST avoids PHP PUT/FILES issue
    $r->put('/drivers/:id/status',           'admin/Drivers@toggleStatus');
    $r->post('/drivers/:id/kyc',            'admin/Drivers@updateKyc');  // multipart — POST avoids PHP PUT/FILES issue
    $r->post('/drivers/:id/assign-vehicle',  'admin/Drivers@assignVehicle');

    // ── Vehicle types ─────────────────────────────────────────────────────────
    $r->get('/vehicle-types',                'admin/VehicleTypes@index');
    $r->post('/vehicle-types',               'admin/VehicleTypes@create');
    $r->put('/vehicle-types/:id',            'admin/VehicleTypes@edit');
    $r->delete('/vehicle-types/:id',         'admin/VehicleTypes@remove');

    // ── Vehicles ──────────────────────────────────────────────────────────────
    $r->get('/vehicles',                     'admin/Vehicles@index');
    $r->post('/vehicles',                    'admin/Vehicles@create');
    $r->get('/vehicles/:id',                 'admin/Vehicles@show');
    $r->post('/vehicles/:id',                'admin/Vehicles@edit');
    $r->put('/vehicles/:id',                 'admin/Vehicles@edit');
    $r->put('/vehicles/:id/status',          'admin/Vehicles@toggleStatus');

    // ── Zones ─────────────────────────────────────────────────────────────────
    $r->get('/zones',                            'admin/Zones@index');
    $r->post('/zones',                           'admin/Zones@create');
    $r->put('/zones/:id',                        'admin/Zones@edit');
    $r->delete('/zones/:id',                     'admin/Zones@remove');
    $r->get('/zones/:id/pricing',                'admin/Zones@pricing');
    $r->post('/zones/:id/pricing',               'admin/Zones@setPricing');
    $r->delete('/zones/:id/pricing/:pricing_id', 'admin/Zones@removePricing');

    // ── Settings ──────────────────────────────────────────────────────────────
    $r->get('/settings',                     'admin/Settings@index');
    $r->put('/settings',                     'admin/Settings@edit');

    // ── Live Chat ─────────────────────────────────────────────────────────────
    $r->put('/live-chat/settings',           'LiveChat@updateSettings');

    // ── SMTP configs ──────────────────────────────────────────────────────────
    $r->get('/smtp-configs',                 'admin/SmtpConfigs@index');
    $r->post('/smtp-configs',                'admin/SmtpConfigs@create');
    $r->put('/smtp-configs/:id',             'admin/SmtpConfigs@updateSmtpConfig');
    $r->put('/smtp-configs/:id/activate',    'admin/SmtpConfigs@activate');
    $r->delete('/smtp-configs/:id',          'admin/SmtpConfigs@remove');
    $r->post('/smtp-configs/test',           'admin/SmtpConfigs@test');

    // ── Email templates ───────────────────────────────────────────────────────
    $r->get('/email-templates',              'admin/EmailTemplates@index');
    $r->post('/email-templates/test',        'admin/EmailTemplates@test');

    // ── Payments ──────────────────────────────────────────────────────────────
    $r->get('/payments',                     'admin/Payments@index');
    $r->get('/payments/:id',                 'admin/Payments@show');
    $r->post('/payments/:id/refund',         'admin/Payments@refund');

    // ── Reports ───────────────────────────────────────────────────────────────
    $r->get('/reports/bookings',             'admin/Reports@bookings');
    $r->get('/reports/revenue',              'admin/Reports@revenue');
    $r->get('/reports/drivers',              'admin/Reports@drivers');

    // ── Trip Reports & Cancellations ───────────────────────────────────────────
    $r->get('/trip-reports',                          'admin/TripReports@index');
    $r->get('/trip-reports/:id',                      'admin/TripReports@show');
    $r->put('/trip-reports/:id/approve-cancellation', 'admin/TripReports@approveCancellation');
    $r->put('/trip-reports/:id/reject-cancellation',  'admin/TripReports@rejectCancellation');

    // ── Account Deletion Requests ──────────────────────────────────────────────
    $r->get('/account-deletion-requests',             'admin/AccountDeletionRequests@index');
    $r->put('/customer-deletion/:id/approve',         'admin/AccountDeletionRequests@approveCustomer');
    $r->put('/customer-deletion/:id/reject',          'admin/AccountDeletionRequests@rejectCustomer');
    $r->put('/driver-deletion/:id/approve',           'admin/AccountDeletionRequests@approveDriver');
    $r->put('/driver-deletion/:id/reject',            'admin/AccountDeletionRequests@rejectDriver');

}, ['auth' => true, 'authType' => 'admin']);
