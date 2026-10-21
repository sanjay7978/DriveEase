-- Figure A.1  Reports
-- Run: mysql -u driveease -pdriveease -t -v --force driveease < report/terminal_outputs/A_1_reports.sql
-- The data is left unchanged, so it can be run any number of times.

CALL report_top_customers(5);
CALL report_pending_dues();
