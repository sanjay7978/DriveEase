-- =====================================================================
-- DriveEase (MySQL 8) - 08_demo_queries.sql
-- Run these one at a time in VS Code (select a statement, then run it)
-- to show every database object working - use for output screenshots.
-- =====================================================================
USE driveease;

-- 1. AUTOMATED TEST CASES (28 tests, all changes rolled back)
CALL run_all_tests();

-- 2. FUNCTIONS used inside SQL
SELECT customer_id, name, dob, fn_customer_age(customer_id, NULL) AS age
  FROM customer ORDER BY customer_id;

SELECT booking_id, status,
       fn_rental_days(booking_id)       AS days,
       fn_rental_amount(booking_id)     AS rent,
       fn_late_fee(booking_id, NULL)    AS late_fee,
       fn_total_paid(booking_id)        AS paid,
       fn_balance_due(booking_id)       AS balance
  FROM booking ORDER BY booking_id;

-- 3. EXPLICIT / NESTED CURSORS
CALL rental_print_customer_history(1001);
CALL report_branch_summary();

-- 4. RESULT-SET reports (module report_*)
CALL report_branch_revenue(6);
CALL report_fleet_utilisation(30);
CALL report_top_customers(5);
CALL report_pending_dues();

-- 5. Availability search (module rental_*)
CALL rental_search_available('Chennai', NULL, NOW() + INTERVAL 3 DAY, NOW() + INTERVAL 5 DAY);

-- 6. Trigger in action: try to book a vehicle under maintenance (error 20003)
CALL rental_create_booking(1003, 112, 508, NULL, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 2 DAY, 0, NULL, @new_booking);

-- 7. Trigger in action: a 19-year-old customer (error 20001)
CALL rental_create_booking(1011, 116, 511, NULL, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 2 DAY, 0, NULL, @new_booking);

-- 8. Audit trail written by the booking triggers
SELECT * FROM booking_audit ORDER BY audit_id DESC LIMIT 15;

-- 9. Every stored object in the database
SELECT routine_type AS object_type, routine_name AS name
  FROM information_schema.routines WHERE routine_schema = 'driveease'
UNION ALL
SELECT 'TRIGGER', CONCAT(trigger_name, '  (', action_timing, ' ', event_manipulation, ' ON ', event_object_table, ')')
  FROM information_schema.triggers WHERE trigger_schema = 'driveease'
UNION ALL
SELECT table_type, table_name FROM information_schema.tables WHERE table_schema = 'driveease'
ORDER BY 1, 2;
