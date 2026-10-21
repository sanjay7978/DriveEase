-- Figure 4.4  Triggers (every statement is rejected on purpose)
-- Run: mysql -u driveease -pdriveease -t -v --force driveease < report/terminal_outputs/4_4_triggers.sql
-- The data is left unchanged, so it can be run any number of times.

CALL rental_create_booking(1011, 116, 511, NULL, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 2 DAY, 0, NULL, @b);
CALL rental_create_booking(1012, 116, 511, NULL, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 8 DAY, 0, NULL, @b);
CALL rental_create_booking(1003, 112, 508, NULL, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 2 DAY, 0, NULL, @b);
CALL rental_create_booking(1007, 101, 502, NULL, (SELECT start_date FROM booking WHERE vehicle_id = 101 AND status = 'BOOKED'), (SELECT end_date FROM booking WHERE vehicle_id = 101 AND status = 'BOOKED') + INTERVAL 1 DAY, 0, NULL, @b);
UPDATE vehicle SET odometer = 100 WHERE vehicle_id = 101;
UPDATE booking SET status = 'BOOKED' WHERE booking_id = 5001;
SELECT audit_id, booking_id, action, old_status, new_status, changed_by FROM booking_audit WHERE booking_id = 5025 ORDER BY audit_id;
