CREATE TABLE IF NOT EXISTS otp_requests (
  id VARCHAR(20) PRIMARY KEY,
  contact VARCHAR(100) NOT NULL,
  contact_type ENUM('email','phone') NOT NULL,
  otp_hash VARCHAR(255) NOT NULL,
  expires_at DATETIME NOT NULL,
  used TINYINT(1) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_contact (contact)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE users MODIFY COLUMN phone VARCHAR(20) NULL DEFAULT NULL;
ALTER TABLE users MODIFY COLUMN name VARCHAR(100) NULL DEFAULT NULL;
ALTER TABLE users MODIFY COLUMN password VARCHAR(255) NULL DEFAULT NULL;

SET @col := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'vehicle_types'
    AND COLUMN_NAME = 'category'
);
SET @sql := IF(
  @col = 0,
  'ALTER TABLE vehicle_types ADD COLUMN category ENUM(''ride'',''delivery'') NOT NULL DEFAULT ''ride'' AFTER description',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bookings'
    AND COLUMN_NAME = 'route_polyline'
);
SET @sql := IF(
  @col = 0,
  'ALTER TABLE bookings ADD COLUMN route_polyline LONGTEXT NULL AFTER num_stops',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bookings'
    AND COLUMN_NAME = 'route_distance_meters'
);
SET @sql := IF(
  @col = 0,
  'ALTER TABLE bookings ADD COLUMN route_distance_meters INT NULL AFTER route_polyline',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'bookings'
    AND COLUMN_NAME = 'route_duration_seconds'
);
SET @sql := IF(
  @col = 0,
  'ALTER TABLE bookings ADD COLUMN route_duration_seconds INT NULL AFTER route_distance_meters',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col := (
  SELECT COUNT(*)
  FROM INFORMATION_SCHEMA.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'vehicle_types'
    AND COLUMN_NAME = 'sort_order'
);
SET @sql := IF(
  @col = 0,
  'ALTER TABLE vehicle_types ADD COLUMN sort_order INT NULL AFTER icon',
  'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
