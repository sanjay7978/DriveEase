-- Figure 4.5  Cursors
-- Run: mysql -u driveease -pdriveease -t -v --force driveease < report/terminal_outputs/4_5_cursors.sql
-- The data is left unchanged, so it can be run any number of times.

CALL rental_print_customer_history(1001);
CALL report_branch_summary();
START TRANSACTION;
CALL fleet_auto_schedule_service(@jobs);
SELECT @jobs AS jobs_created;
SELECT maint_id, vehicle_id, service_type, description, maint_status FROM maintenance WHERE description LIKE 'Auto:%' ORDER BY maint_id DESC LIMIT 5;
ROLLBACK;
