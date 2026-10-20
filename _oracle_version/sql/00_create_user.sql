-- =====================================================================
-- DriveEase - Vehicle Rental Management System
-- 00_create_user.sql
-- Run ONCE as SYS (or SYSTEM) connected to the pluggable database XEPDB1.
--   SQL Developer: connect as  sys / <password>  role SYSDBA,
--                  service name XEPDB1, then run this script (F5).
-- Creates the application schema DRIVEEASE that owns every object.
-- =====================================================================
ALTER SESSION SET CONTAINER = XEPDB1;

CREATE USER driveease IDENTIFIED BY driveease
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE TYPE, CREATE SYNONYM
   TO driveease;
GRANT EXECUTE ON SYS.DBMS_OUTPUT TO driveease;
