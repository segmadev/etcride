-- Migration 005: Full booking lifecycle columns
-- Run once: php scripts/schema.php  (or execute directly in phpMyAdmin)
-- All statements are idempotent (IF NOT EXISTS / MODIFY only changes if needed).

-- 1. Add 'arrived' to the status ENUM
ALTER TABLE `bookings`
    MODIFY COLUMN `status` ENUM(
        'pending',
        'assigned',
        'accepted',
        'arrived',
        'in_progress',
        'payment_pending',
        'paid',
        'completed',
        'cancelled',
        'rejected'
    ) NOT NULL DEFAULT 'pending';

-- 2. Add payment_method column (customer/driver chosen method)
ALTER TABLE `bookings`
    ADD COLUMN IF NOT EXISTS `payment_method`
        ENUM('cash','bank_transfer','flutterwave') NULL
        AFTER `pay_mode_snapshot`;

-- 3. Add customer rating columns
ALTER TABLE `bookings`
    ADD COLUMN IF NOT EXISTS `customer_rating`  TINYINT UNSIGNED NULL AFTER `payment_method`,
    ADD COLUMN IF NOT EXISTS `customer_comment` TEXT NULL          AFTER `customer_rating`;

-- 4. Index to speed up driver rating recalculation
ALTER TABLE `bookings`
    ADD INDEX IF NOT EXISTS `idx_bookings_driver_rating` (`driver_id`, `customer_rating`);
