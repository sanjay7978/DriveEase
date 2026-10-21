-- Figure 4.3  Packages (rental_* module)
-- Run: mysql -u driveease -pdriveease -t -v --force driveease < report/terminal_outputs/4_3_packages.sql
-- The data is left unchanged, so it can be run any number of times.

CALL rental_search_available('Chennai', NULL, NOW() + INTERVAL 3 DAY, NOW() + INTERVAL 5 DAY);
START TRANSACTION;
SET @start = NOW() + INTERVAL 1 HOUR;
CALL rental_create_booking(1007, 116, 511, 4, @start, @start + INTERVAL 2 DAY, 500, 'UPI', @bk);
SELECT @bk AS booking_id, fn_rental_amount(@bk) AS rent, fn_total_paid(@bk) AS advance_paid;
CALL rental_record_pickup(@bk, 5000);
SELECT b.booking_id, b.status AS booking_status, v.status AS vehicle_status FROM booking b JOIN vehicle v USING (vehicle_id) WHERE b.booking_id = @bk;
CALL rental_record_return(@bk, 5180, @start + INTERVAL 2 DAY + INTERVAL 3 HOUR, 'UPI', @due);
SELECT @due AS balance_after_settlement, fn_late_fee(@bk, NULL) AS late_fee;
SELECT payment_type, method, amount FROM payment WHERE booking_id = @bk ORDER BY payment_id;
ROLLBACK;
