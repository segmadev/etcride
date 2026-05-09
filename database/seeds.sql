-- =============================================================================
-- EtcRide — Default Seed Data
-- All inserts use INSERT IGNORE — safe to run multiple times (idempotent).
-- =============================================================================

-- =============================================================================
-- DEFAULT ZONE  (Kwara State — required fallback, must always exist)
-- =============================================================================
INSERT IGNORE INTO `zones` (`id`, `name`, `description`, `is_default`, `is_active`) VALUES
('ZNE_DEFAULT_001', 'Default (Kwara State)', 'Default pricing zone covering all of Kwara State', 1, 1);

-- =============================================================================
-- PLATFORM SETTINGS  (All admin-configurable toggles and values)
-- =============================================================================
INSERT IGNORE INTO `settings` (`config_key`, `config_value`, `description`) VALUES

-- Driver assignment
('auto_assign_enabled',               '1',               'Auto-assign nearest available driver (1=on, 0=off)'),
('driver_search_radius_km',           '10',              'Search radius (km) for auto-assignment'),

-- Fare / distance
('calc_method',                       'server',          'Distance method: server (Haversine) | app (client-provided)'),

-- Payment
('pay_mode',                          'pay_on_booking',  'Payment timing: pay_on_booking | pay_on_completion'),
('payment_provider',                  'flutterwave',     'Default payment provider: flutterwave | monnify'),

-- Cancellation
('cancellation_allowed_by',           'customer',        'Who can cancel: customer | driver | both | none'),
('cancellation_window_minutes',       '5',               'Free-cancel grace period in minutes after booking creation'),
('cancellation_fee_enabled',          '0',               'Charge a cancellation fee (1=yes, 0=no)'),
('cancellation_fee_amount',           '0.00',            'Cancellation fee amount in NGN'),
('cancellation_fee_after_assignment', '0',               'Apply fee only after a driver has been assigned (1=yes, 0=no)'),

-- Notifications
('fcm_enabled',                       '1',               'Enable Firebase push notifications globally (1=on, 0=off)'),
('email_notifications_enabled',       '1',               'Enable email notifications globally (1=on, 0=off)'),

-- Currency & fares
('currency',                          'NGN',             'Platform currency code'),
('currency_symbol',                   '₦',               'Platform currency symbol'),
('min_booking_fare',                  '200.00',          'Minimum fare for any booking in NGN'),

-- App info
('app_name',                          'EtcRide',         'Application display name'),
('support_email',                     '',                'Customer support email address'),
('support_phone',                     '',                'Customer support phone number');
