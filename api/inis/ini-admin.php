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

    // ── Drivers ───────────────────────────────────────────────────────────────
    $r->get('/drivers',                      'admin/Drivers@index');
    $r->post('/drivers',                     'admin/Drivers@create');
    $r->get('/drivers/:id',                  'admin/Drivers@show');
    $r->put('/drivers/:id',                  'admin/Drivers@edit');
    $r->put('/drivers/:id/status',           'admin/Drivers@toggleStatus');
    $r->put('/drivers/:id/kyc',             'admin/Drivers@updateKyc');
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

    // ── Email templates ───────────────────────────────────────────────────────
    $r->get('/email-templates',              'admin/EmailTemplates@index');
    $r->post('/email-templates/test',        'admin/EmailTemplates@test');

    // ── Reports ───────────────────────────────────────────────────────────────
    $r->get('/reports/bookings',             'admin/Reports@bookings');
    $r->get('/reports/revenue',              'admin/Reports@revenue');
    $r->get('/reports/drivers',              'admin/Reports@drivers');

}, ['auth' => true, 'authType' => 'admin']);
