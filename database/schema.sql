-- =============================================================================
-- EtcRide — Full Database Schema
-- Engine: MySQL 8+  |  Charset: utf8mb4_unicode_ci  |  Currency: NGN
-- State: Kwara, Nigeria
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =============================================================================
-- USERS  (Customers — self-register via mobile app)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `users` (
    `id`                VARCHAR(20)  NOT NULL,
    `name`              VARCHAR(100) NULL DEFAULT NULL,
    `email`             VARCHAR(150) NULL,
    `phone`             VARCHAR(20)  NULL DEFAULT NULL,
    `password`          VARCHAR(255) NULL DEFAULT NULL,
    `fcm_token`         TEXT         NULL,           -- Firebase push token
    `status`            TINYINT(1)   NOT NULL DEFAULT 0,  -- 0=unverified 1=active 2=suspended
    `email_verified_at` TIMESTAMP    NULL,
    `reset_code`        VARCHAR(255) NULL,           -- bcrypt-hashed OTP
    `created_at`        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_users_email` (`email`),
    UNIQUE KEY `uq_users_phone` (`phone`),
    INDEX `idx_users_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- USER SESSIONS  (Customer bearer tokens)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `user_sessions` (
    `id`         VARCHAR(20)  NOT NULL,
    `user_id`    VARCHAR(20)  NOT NULL,
    `token`      VARCHAR(100) NOT NULL,
    `expires_at` TIMESTAMP    NOT NULL,
    `device`     VARCHAR(255) NULL,
    `ip`         VARCHAR(45)  NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_user_sessions_token` (`token`),
    INDEX `idx_user_sessions_user`    (`user_id`),
    INDEX `idx_user_sessions_expires` (`expires_at`),
    CONSTRAINT `fk_user_sessions_user`
        FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- OTP REQUESTS  (Email/phone OTP auth)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `otp_requests` (
    `id`           VARCHAR(20) PRIMARY KEY,
    `contact`      VARCHAR(100) NOT NULL,
    `contact_type` ENUM('email','phone') NOT NULL,
    `otp_hash`     VARCHAR(255) NOT NULL,
    `expires_at`   DATETIME NOT NULL,
    `used`         TINYINT(1) DEFAULT 0,
    `created_at`   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_contact` (`contact`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Ensure OTP auth supports creating "minimal" users (email-only or phone-only)
ALTER TABLE `users` MODIFY COLUMN `phone` VARCHAR(20) NULL DEFAULT NULL;
ALTER TABLE `users` MODIFY COLUMN `name` VARCHAR(100) NULL DEFAULT NULL;
ALTER TABLE `users` MODIFY COLUMN `password` VARCHAR(255) NULL DEFAULT NULL;

-- =============================================================================
-- VEHICLE TYPES  (Admin-defined groups — carry default fare rates)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `vehicle_types` (
    `id`           VARCHAR(20)    NOT NULL,
    `name`         VARCHAR(100)   NOT NULL,   -- e.g. Motorcycle, Tricycle, Car
    `description`  TEXT           NULL,
    `category`     ENUM('ride','delivery') NOT NULL DEFAULT 'ride',
    `icon`         VARCHAR(255)   NULL,        -- icon slug/url for mobile display
    `sort_order`   INT            NULL,
    `base_fare`    DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    `per_km_rate`  DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    `per_stop_fee` DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
    `is_active`    TINYINT(1)     NOT NULL DEFAULT 1,
    `created_at`   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_vehicle_types_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- VEHICLES  (Individual vehicles — admin-created, assigned to a type)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `vehicles` (
    `id`              VARCHAR(20)             NOT NULL,
    `vehicle_type_id` VARCHAR(20)             NOT NULL,
    `plate_number`    VARCHAR(20)             NOT NULL,
    `make`            VARCHAR(100)            NULL,     -- brand e.g. Honda
    `model`           VARCHAR(100)            NULL,     -- e.g. CB125
    `color`           VARCHAR(50)             NULL,
    `year`            YEAR                    NULL,
    `status`          ENUM('active','inactive') NOT NULL DEFAULT 'active',
    `created_at`      TIMESTAMP               NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      TIMESTAMP               NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_vehicles_plate` (`plate_number`),
    INDEX `idx_vehicles_type` (`vehicle_type_id`),
    INDEX `idx_vehicles_status` (`status`),
    CONSTRAINT `fk_vehicles_type`
        FOREIGN KEY (`vehicle_type_id`) REFERENCES `vehicle_types` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- DRIVERS  (Admin-created accounts — cannot self-register)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `drivers` (
    `id`          VARCHAR(20)  NOT NULL,
    `name`        VARCHAR(100) NOT NULL,
    `email`       VARCHAR(150) NULL,
    `phone`       VARCHAR(20)  NOT NULL,
    `password`    VARCHAR(255) NOT NULL,
    `vehicle_id`  VARCHAR(20)  NULL,          -- currently assigned vehicle
    `fcm_token`   TEXT         NULL,
    `photo`       VARCHAR(500) NULL,
    `rating`      DECIMAL(3,1) NOT NULL DEFAULT 0.0,
    `is_active`   TINYINT(1)   NOT NULL DEFAULT 1,   -- admin enable/disable
    `is_online`   TINYINT(1)   NOT NULL DEFAULT 0,   -- driver self-toggle
    `last_lat`    DECIMAL(10,8) NULL,
    `last_lng`    DECIMAL(11,8) NULL,
    `last_seen`   TIMESTAMP    NULL,
    `reset_code`  VARCHAR(255) NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_drivers_email` (`email`),
    UNIQUE KEY `uq_drivers_phone` (`phone`),
    INDEX `idx_drivers_online_active` (`is_online`, `is_active`),
    INDEX `idx_drivers_location`      (`last_lat`, `last_lng`),
    CONSTRAINT `fk_drivers_vehicle`
        FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- DRIVER SESSIONS  (Driver bearer tokens)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `driver_sessions` (
    `id`         VARCHAR(20)  NOT NULL,
    `driver_id`  VARCHAR(20)  NOT NULL,
    `token`      VARCHAR(100) NOT NULL,
    `expires_at` TIMESTAMP    NOT NULL,
    `device`     VARCHAR(255) NULL,
    `ip`         VARCHAR(45)  NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_driver_sessions_token` (`token`),
    INDEX `idx_driver_sessions_driver`  (`driver_id`),
    INDEX `idx_driver_sessions_expires` (`expires_at`),
    CONSTRAINT `fk_driver_sessions_driver`
        FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- ADMIN  (Platform administrators)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `admin` (
    `id`         VARCHAR(20)  NOT NULL,
    `name`       VARCHAR(100) NOT NULL,
    `email`      VARCHAR(150) NOT NULL,
    `password`   VARCHAR(255) NOT NULL,
    `token`      VARCHAR(255) NULL,
    `role`       VARCHAR(50)  NOT NULL DEFAULT 'admin',
    `status`     TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_admin_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- ZONES  (Kwara State geographic sub-areas)
-- One zone must have is_default=1 as the fallback for the whole state.
-- Pricing lookup: zone_pricing → fallback to vehicle_types defaults
-- =============================================================================
CREATE TABLE IF NOT EXISTS `zones` (
    `id`          VARCHAR(20)  NOT NULL,
    `name`        VARCHAR(100) NOT NULL,  -- e.g. "Default (Kwara)", "Ilorin Central"
    `description` TEXT         NULL,
    `is_default`  TINYINT(1)   NOT NULL DEFAULT 0,  -- fallback zone for unmatched bookings
    `is_active`   TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_zones_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- ZONE PRICING  (Per-zone, per-vehicle-type fare overrides)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `zone_pricing` (
    `id`              VARCHAR(20)   NOT NULL,
    `zone_id`         VARCHAR(20)   NOT NULL,
    `vehicle_type_id` VARCHAR(20)   NOT NULL,
    `base_fare`       DECIMAL(10,2) NOT NULL,
    `per_km_rate`     DECIMAL(10,2) NOT NULL,
    `per_stop_fee`    DECIMAL(10,2) NOT NULL,
    `is_active`       TINYINT(1)    NOT NULL DEFAULT 1,
    `created_at`      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_zone_pricing` (`zone_id`, `vehicle_type_id`),
    CONSTRAINT `fk_zone_pricing_zone`
        FOREIGN KEY (`zone_id`) REFERENCES `zones` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_zone_pricing_type`
        FOREIGN KEY (`vehicle_type_id`) REFERENCES `vehicle_types` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SETTINGS  (Platform-wide configuration — key/value)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `settings` (
    `id`          INT          NOT NULL AUTO_INCREMENT,
    `config_key`  VARCHAR(100) NOT NULL,
    `config_value` TEXT        NOT NULL,
    `description` VARCHAR(255) NULL,
    `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_settings_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- BOOKINGS  (Core booking record — rides and deliveries)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `bookings` (
    `id`            VARCHAR(20) NOT NULL,
    `booking_code`  VARCHAR(20) NOT NULL,
    `customer_id`   VARCHAR(20) NOT NULL,
    `driver_id`     VARCHAR(20) NULL,
    `vehicle_type_id` VARCHAR(20) NULL,
    `zone_id`       VARCHAR(20) NULL,

    `booking_type`  ENUM('ride','delivery') NOT NULL DEFAULT 'ride',
    `status`        ENUM(
                        'pending',        -- created, awaiting assignment
                        'assigned',       -- driver assigned (manual or auto)
                        'accepted',       -- driver accepted job, en route to pickup
                        'arrived',        -- driver arrived at pickup location
                        'in_progress',    -- trip started
                        'payment_pending',-- trip done, awaiting customer payment
                        'paid',           -- payment confirmed
                        'completed',      -- fully done
                        'cancelled',      -- cancelled per platform rules
                        'rejected'        -- driver rejected → goes back to pending
                    ) NOT NULL DEFAULT 'pending',

    -- Pickup
    `pickup_address` TEXT         NOT NULL,
    `pickup_lat`     DECIMAL(10,8) NOT NULL,
    `pickup_lng`     DECIMAL(11,8) NOT NULL,

    -- Destination
    `destination_address` TEXT         NOT NULL,
    `destination_lat`     DECIMAL(10,8) NOT NULL,
    `destination_lng`     DECIMAL(11,8) NOT NULL,

    -- Fare
    `estimated_fare` DECIMAL(10,2) NULL,
    `final_fare`     DECIMAL(10,2) NULL,
    `distance_km`    DECIMAL(8,2)  NULL,  -- server-calculated or app-provided
    `num_stops`      INT           NOT NULL DEFAULT 0,

    -- Delivery-only fields (NULL for rides)
    `recipient_name`        VARCHAR(100) NULL,
    `recipient_phone`       VARCHAR(20)  NULL,
    `package_description`   TEXT         NULL,
    `package_size`          ENUM('small','medium','large') NULL,

    -- Payment
    `payment_status`    ENUM('pending','paid','failed') NOT NULL DEFAULT 'pending',
    `pay_mode_snapshot` ENUM('pay_on_booking','pay_on_completion') NOT NULL,  -- snapshot at creation
    `payment_method`    ENUM('cash','bank_transfer','flutterwave') NULL,      -- chosen at payment time

    -- Rating
    `customer_rating`   TINYINT UNSIGNED NULL,
    `customer_comment`  TEXT             NULL,

    -- Cancellation
    `cancelled_by_role`         ENUM('customer','driver','admin') NULL,
    `cancelled_by_id`           VARCHAR(20)   NULL,
    `cancellation_reason`       TEXT          NULL,
    `cancellation_fee_charged`  DECIMAL(10,2) NOT NULL DEFAULT 0.00,

    `notes`      TEXT      NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_bookings_code` (`booking_code`),
    INDEX `idx_bookings_customer` (`customer_id`),
    INDEX `idx_bookings_driver`   (`driver_id`),
    INDEX `idx_bookings_status`   (`status`),
    INDEX `idx_bookings_type`     (`booking_type`),
    INDEX `idx_bookings_created`  (`created_at`),

    CONSTRAINT `fk_bookings_customer`
        FOREIGN KEY (`customer_id`) REFERENCES `users` (`id`),
    CONSTRAINT `fk_bookings_driver`
        FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bookings_vehicle_type`
        FOREIGN KEY (`vehicle_type_id`) REFERENCES `vehicle_types` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bookings_zone`
        FOREIGN KEY (`zone_id`) REFERENCES `zones` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- BOOKING STOPS  (Ordered waypoints within a booking)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `booking_stops` (
    `id`         VARCHAR(20)  NOT NULL,
    `booking_id` VARCHAR(20)  NOT NULL,
    `stop_order` INT          NOT NULL,  -- 1-based sort order
    `address`    TEXT         NOT NULL,
    `lat`        DECIMAL(10,8) NOT NULL,
    `lng`        DECIMAL(11,8) NOT NULL,
    `status`     ENUM('pending','reached') NOT NULL DEFAULT 'pending',
    `reached_at` TIMESTAMP    NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_stops_booking` (`booking_id`),
    CONSTRAINT `fk_stops_booking`
        FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- BOOKING STATUS HISTORY  (Immutable audit trail of status transitions)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `booking_status_history` (
    `id`              VARCHAR(20) NOT NULL,
    `booking_id`      VARCHAR(20) NOT NULL,
    `from_status`     VARCHAR(30) NULL,
    `to_status`       VARCHAR(30) NOT NULL,
    `changed_by_role` ENUM('customer','driver','admin','system') NOT NULL,
    `changed_by_id`   VARCHAR(20) NULL,
    `note`            TEXT        NULL,
    `created_at`      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_bsh_booking` (`booking_id`),
    CONSTRAINT `fk_bsh_booking`
        FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- TRIPS  (One trip record per booking once driver starts)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `trips` (
    `id`                 VARCHAR(20) NOT NULL,
    `booking_id`         VARCHAR(20) NOT NULL,
    `driver_id`          VARCHAR(20) NOT NULL,
    `started_at`         TIMESTAMP   NULL,
    `completed_at`       TIMESTAMP   NULL,
    `distance_actual_km` DECIMAL(8,2) NULL,
    `status`             ENUM('active','completed','cancelled') NOT NULL DEFAULT 'active',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_trips_booking`  (`booking_id`),
    INDEX `idx_trips_driver` (`driver_id`),
    INDEX `idx_trips_status` (`status`),
    CONSTRAINT `fk_trips_booking`
        FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`),
    CONSTRAINT `fk_trips_driver`
        FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- DRIVER LOCATION LOGS  (High-volume append-only location pings)
-- Written every N seconds while trip is in_progress.
-- Customers/admin read last known from drivers.last_lat/last_lng (faster).
-- =============================================================================
CREATE TABLE IF NOT EXISTS `driver_location_logs` (
    `id`          BIGINT        NOT NULL AUTO_INCREMENT,
    `driver_id`   VARCHAR(20)   NOT NULL,
    `trip_id`     VARCHAR(20)   NULL,
    `lat`         DECIMAL(10,8) NOT NULL,
    `lng`         DECIMAL(11,8) NOT NULL,
    `recorded_at` TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_dll_driver_trip` (`driver_id`, `trip_id`),
    INDEX `idx_dll_recorded`    (`recorded_at`),
    CONSTRAINT `fk_dll_driver`
        FOREIGN KEY (`driver_id`) REFERENCES `drivers` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_dll_trip`
        FOREIGN KEY (`trip_id`) REFERENCES `trips` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- PAYMENTS  (Flutterwave / Monnify transaction records)
-- `reference` is our idempotency key — checked on every webhook to avoid double-processing.
-- =============================================================================
CREATE TABLE IF NOT EXISTS `payments` (
    `id`           VARCHAR(20)  NOT NULL,
    `booking_id`   VARCHAR(20)  NOT NULL,
    `provider`     ENUM('flutterwave','monnify') NOT NULL,
    `amount`       DECIMAL(10,2) NOT NULL,
    `currency`     VARCHAR(5)    NOT NULL DEFAULT 'NGN',
    `status`       ENUM('pending','paid','failed','refunded') NOT NULL DEFAULT 'pending',
    `reference`    VARCHAR(100)  NOT NULL,   -- our generated ref (idempotency key)
    `provider_ref` VARCHAR(100)  NULL,        -- provider's own transaction ref
    `raw_response` JSON          NULL,        -- full webhook/callback payload
    `created_at`   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_payments_reference` (`reference`),
    INDEX `idx_payments_booking`  (`booking_id`),
    INDEX `idx_payments_status`   (`status`),
    CONSTRAINT `fk_payments_booking`
        FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- NOTIFICATIONS  (FCM push + in-app notification store)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `notifications` (
    `id`             VARCHAR(20)  NOT NULL,
    `recipient_role` ENUM('customer','driver','admin') NOT NULL,
    `recipient_id`   VARCHAR(20)  NOT NULL,
    `title`          VARCHAR(255) NOT NULL,
    `body`           TEXT         NOT NULL,
    `type`           VARCHAR(50)  NULL,  -- booking_created|driver_assigned|driver_accepted|
                                         -- payment_confirmed|trip_started|stop_reached|
                                         -- trip_completed|booking_cancelled
    `booking_id`     VARCHAR(20)  NULL,
    `is_read`        TINYINT(1)   NOT NULL DEFAULT 0,
    `created_at`     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_notif_recipient` (`recipient_role`, `recipient_id`),
    INDEX `idx_notif_unread`    (`is_read`),
    INDEX `idx_notif_created`   (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- ACTIVITIES  (Audit log — append-only, high volume)
-- =============================================================================
CREATE TABLE IF NOT EXISTS `activities` (
    `id`         BIGINT       NOT NULL AUTO_INCREMENT,
    `actor_role` ENUM('customer','driver','admin','system') NOT NULL,
    `actor_id`   VARCHAR(20)  NULL,
    `action`     VARCHAR(100) NOT NULL,
    `ip`         VARCHAR(45)  NULL,
    `device`     VARCHAR(255) NULL,
    `meta`       JSON         NULL,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_activities_actor`   (`actor_role`, `actor_id`),
    INDEX `idx_activities_action`  (`action`),
    INDEX `idx_activities_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
