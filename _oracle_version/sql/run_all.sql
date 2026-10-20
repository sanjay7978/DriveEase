-- =====================================================================
-- DriveEase - run_all.sql : builds the whole schema in the right order.
-- Connect as DRIVEEASE (service XEPDB1) and run this file with F5
-- in SQL Developer, or:  sqlplus driveease/driveease@//localhost:1521/XEPDB1 @run_all.sql
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON
@@01_tables.sql
@@02_functions.sql
@@03_procedures.sql
@@04_packages.sql
@@05_triggers.sql
@@06_seed_data.sql
@@07_test_package.sql

PROMPT ==== Object status (all should be VALID) ====
SELECT object_type, object_name, status FROM user_objects
 WHERE object_type IN ('FUNCTION','PROCEDURE','PACKAGE','PACKAGE BODY','TRIGGER')
 ORDER BY object_type, object_name;
