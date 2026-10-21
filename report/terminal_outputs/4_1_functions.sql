-- Figure 4.1  Functions
-- Run: mysql -u driveease -pdriveease -t -v --force driveease < report/terminal_outputs/4_1_functions.sql
-- The data is left unchanged, so it can be run any number of times.

SELECT customer_id, name, dob, fn_customer_age(customer_id, NULL) AS age FROM customer WHERE customer_id IN (1001, 1005, 1011);
SELECT booking_id, status, fn_rental_days(booking_id) AS days, fn_rental_amount(booking_id) AS rent, fn_late_fee(booking_id, NULL) AS late_fee, fn_total_paid(booking_id) AS paid, fn_balance_due(booking_id) AS balance FROM booking WHERE booking_id IN (5003, 5015, 5021, 5025, 5028);
SELECT vehicle_id, reg_number, status, fn_is_vehicle_available(vehicle_id, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 2 DAY) AS free_tomorrow FROM vehicle WHERE vehicle_id IN (101, 104, 112, 120);
