-- =====================================================================
-- DriveEase - Vehicle Rental Management System  (MySQL 8 version)
-- 00_create_database.sql
-- Run ONCE as the MySQL root user. Creates the database and the
-- application user.
-- =====================================================================
CREATE DATABASE IF NOT EXISTS driveease
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

CREATE USER IF NOT EXISTS 'driveease'@'localhost' IDENTIFIED BY 'driveease';
GRANT ALL PRIVILEGES ON driveease.* TO 'driveease'@'localhost';
FLUSH PRIVILEGES;

-- allow a normal user to create stored functions and triggers
-- while binary logging is on (MySQL default)
SET PERSIST log_bin_trust_function_creators = 1;
