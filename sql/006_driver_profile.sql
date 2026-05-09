-- Migration 006: Add photo and rating columns to drivers table
-- Run once in phpMyAdmin or via MySQL CLI.

ALTER TABLE `drivers`
    ADD COLUMN IF NOT EXISTS `photo`  VARCHAR(500)      NULL AFTER `fcm_token`,
    ADD COLUMN IF NOT EXISTS `rating` DECIMAL(3,1)  NOT NULL DEFAULT 0.0 AFTER `photo`;

-- Index to speed up driver rating lookups
ALTER TABLE `drivers`
    ADD INDEX IF NOT EXISTS `idx_drivers_rating` (`rating`);
