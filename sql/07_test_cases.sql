-- =====================================================================
-- DriveEase (MySQL 8) - 07_test_cases.sql : automated TEST CASES
--
--   CALL run_all_tests();
--
-- Returns one row per test: tc | result | area | test_case | actual_output
-- Everything the tests change is ROLLED BACK at the end, and the tests
-- create their own test vehicles, so they pass on any state of the data.
-- =====================================================================
USE driveease;

DROP PROCEDURE IF EXISTS t_result;
DROP PROCEDURE IF EXISTS t_expect;
DROP PROCEDURE IF EXISTS run_all_tests;

DELIMITER $$

-- record one test result (test_result is a MEMORY table, so the final
-- ROLLBACK of the test data does not remove the results)
CREATE PROCEDURE t_result (p_tc VARCHAR(6), p_ok BOOLEAN, p_area VARCHAR(10),
                           p_test VARCHAR(160), p_actual VARCHAR(250))
BEGIN
  INSERT INTO test_result (tc, result, area, test_case, actual_output)
  VALUES (p_tc, IF(p_ok, 'PASS', 'FAIL'), p_area, p_test, LEFT(COALESCE(p_actual, 'NULL'), 250));
END$$

-- negative test: PASS when the expected error number was raised
CREATE PROCEDURE t_expect (p_tc VARCHAR(6), p_area VARCHAR(10), p_test VARCHAR(160),
                           p_expected INT, p_got INT, p_msg VARCHAR(512))
BEGIN
  CALL t_result(p_tc, p_got = p_expected, p_area, p_test,
                IF(p_got = 0, CONCAT('No error raised (expected error ', p_expected, ')'),
                              CONCAT('Rejected with error ', p_got, ': ', p_msg)));
END$$

CREATE PROCEDURE run_all_tests ()
BEGIN
  DECLARE v_start  DATETIME DEFAULT CURDATE() + INTERVAL 20 DAY + INTERVAL 9 HOUR;  -- quiet future window
  DECLARE v_prev_autocommit INT DEFAULT @@autocommit;
  DECLARE v_errno  INT DEFAULT 0;
  DECLARE v_msg    VARCHAR(512);
  DECLARE v_n      INT;
  DECLARE v_n2     INT;
  DECLARE v_s      VARCHAR(200);
  DECLARE v_id     INT;
  DECLARE v_bk     INT;
  DECLARE v_bk2    INT;
  DECLARE v_bk5    INT;
  DECLARE v_amt    DECIMAL(10,2);
  DECLARE v_amt2   DECIMAL(10,2);
  DECLARE v_end    DATETIME;
  DECLARE v_mark   INT;
  DECLARE t1, t2, t3, t4, t5 INT;              -- private test vehicles

  DROP TEMPORARY TABLE IF EXISTS test_result;
  CREATE TEMPORARY TABLE test_result (
    tc VARCHAR(6), result VARCHAR(4), area VARCHAR(10),
    test_case VARCHAR(160), actual_output VARCHAR(250)) ENGINE = MEMORY;

  SET autocommit = 0;
  SAVEPOINT test_start;

  -- ---------- set-up: own test vehicles (all rolled back at the end) ----------
  CALL sp_add_vehicle('TST0001', 'Test', 'Hatch A', 2025, 'PETROL', 'MANUAL',  100, 1, 1, t1);
  CALL sp_add_vehicle('TST0002', 'Test', 'Sedan',   2025, 'PETROL', 'MANUAL',  100, 2, 1, t2);
  CALL sp_add_vehicle('TST0003', 'Test', 'SUV',     2025, 'DIESEL', 'MANUAL',  100, 3, 1, t3);
  CALL sp_add_vehicle('TST0004', 'Test', 'Hatch B', 2025, 'PETROL', 'MANUAL', 1000, 1, 1, t4);
  CALL sp_add_vehicle('TST0005', 'Test', 'Hatch C', 2025, 'PETROL', 'MANUAL',  500, 1, 1, t5);
  CALL fleet_schedule_maintenance(t2, 'REPAIR', 'Test set-up', NOW(), v_id);       -- t2 under maintenance
  CALL rental_create_booking(1001, t5, 502, NULL, NOW() + INTERVAL 1 HOUR,
                             NOW() + INTERVAL 1 HOUR + INTERVAL 2 DAY, 0, NULL, v_bk5);
  CALL rental_record_pickup(v_bk5, 500);                                           -- t5 rented out

  -- ======================= FUNCTIONS =======================
  SET v_n  = fn_customer_age(1001, NULL);
  SET v_n2 = TIMESTAMPDIFF(YEAR, '1996-04-10', CURDATE());
  CALL t_result('TC01', v_n = v_n2, 'Function', 'fn_customer_age(1001) derives age from DOB 10-Apr-1996',
                CONCAT('Returned ', v_n, ' (expected ', v_n2, ')'));

  SET v_s = CONCAT(fn_is_vehicle_available(t2, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 2 DAY), '/',
                   fn_is_vehicle_available(t1, v_start, v_start + INTERVAL 2 DAY));
  CALL t_result('TC02', v_s = 'N/Y', 'Function',
                'fn_is_vehicle_available: vehicle in MAINTENANCE -> N, free vehicle -> Y', CONCAT('Returned ', v_s));

  -- ======================= PROCEDURES =======================
  CALL sp_register_customer('Test Customer', '9000000001', 'test.customer@example.com', 'TN99TEST0001',
                            CURDATE() + INTERVAL 5 YEAR, '1998-01-01', 'Vellore', v_id);
  SELECT COUNT(*) INTO v_n FROM customer WHERE customer_id = v_id;
  CALL t_result('TC03', v_n = 1, 'Procedure', 'sp_register_customer registers a valid customer (FR-01)',
                CONCAT('Customer ', v_id, ' created'));

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    CALL sp_register_customer('Duplicate Licence', '9000000002', NULL, 'TN99TEST0001',
                              CURDATE() + INTERVAL 5 YEAR, '1998-01-01', NULL, v_id);
  END;
  CALL t_expect('TC04', 'Procedure', 'sp_register_customer rejects a duplicate licence number', 20020, v_errno, v_msg);

  CALL sp_add_vehicle('TN23ZZ9999', 'Maruti', 'Ertiga', 2025, 'CNG', 'MANUAL', 100, 3, 1, v_id);
  SELECT status INTO v_s FROM vehicle WHERE vehicle_id = v_id;
  CALL t_result('TC05', v_s = 'AVAILABLE', 'Procedure',
                'sp_add_vehicle adds a vehicle with default status AVAILABLE (FR-02)',
                CONCAT('Vehicle ', v_id, ' status ', v_s));

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    CALL sp_retire_vehicle(t5);
  END;
  CALL t_expect('TC06', 'Procedure', 'sp_retire_vehicle refuses a vehicle that has an open booking', 20024, v_errno, v_msg);

  -- ======================= MODULE rental_* =======================
  CALL rental_create_booking(1007, t1, 502, NULL, v_start, v_start + INTERVAL 3 DAY, 1000, 'UPI', v_bk);
  SELECT COUNT(*) INTO v_n FROM payment WHERE booking_id = v_bk AND payment_type = 'ADVANCE';
  SET v_amt = fn_rental_amount(v_bk);
  CALL t_result('TC07', v_n = 1 AND v_amt = 4500 AND fn_rental_days(v_bk) = 3, 'Module',
                'rental_create_booking: booking + advance in one transaction; rent = 3 days x Rs.1500 (BR-04)',
                CONCAT('Booking ', v_bk, ', advance rows ', v_n, ', fn_rental_days ', fn_rental_days(v_bk),
                       ', fn_rental_amount ', v_amt));

  SELECT COUNT(*), SUM(vehicle_id = t1) INTO v_n, v_n2
    FROM v_vehicle_catalog
   WHERE category_id = 1
     AND fn_is_vehicle_available(vehicle_id, v_start + INTERVAL 1 DAY, v_start + INTERVAL 2 DAY) = 'Y';
  CALL t_result('TC08', v_n > 0 AND v_n2 = 0, 'Module',
                'rental_search_available logic (view + fn_is_vehicle_available) hides the vehicle booked in TC07 (FR-03)',
                CONCAT(v_n, ' hatchbacks free; vehicle ', t1, ' listed: ', IF(v_n2 = 1, 'YES', 'NO')));

  CALL rental_create_booking(1002, t4, 502, 2, NOW() + INTERVAL 2 HOUR,
                             NOW() + INTERVAL 2 HOUR + INTERVAL 1 DAY, 500, 'CASH', v_bk2);
  CALL rental_record_pickup(v_bk2, 1000);
  SELECT CONCAT(b.status, '/', v.status) INTO v_s
    FROM booking b JOIN vehicle v ON v.vehicle_id = b.vehicle_id WHERE b.booking_id = v_bk2;
  CALL t_result('TC09', v_s = 'ONGOING/RENTED', 'Module',
                'rental_record_pickup: booking -> ONGOING, vehicle -> RENTED (FR-05)',
                CONCAT('Booking ', v_bk2, ' / vehicle ', t4, ' = ', v_s));

  SELECT end_date INTO v_end FROM booking WHERE booking_id = v_bk2;
  SET v_amt2 = fn_late_fee(v_bk2, v_end + INTERVAL 150 MINUTE);    -- "what-if" 2.5 h late -> 3 h charged
  CALL rental_record_return(v_bk2, 1150, v_end + INTERVAL 3 HOUR, 'UPI', v_amt);
  SELECT CONCAT(status, '/branch ', branch_id, '/odo ', odometer) INTO v_s FROM vehicle WHERE vehicle_id = t4;
  CALL t_result('TC10', fn_late_fee(v_bk2, NULL) = 300 AND v_amt2 = 300 AND v_amt = 0
                        AND v_s = 'AVAILABLE/branch 2/odo 1150', 'Module',
                'rental_record_return 3 h late, one-way to branch 2: late fee 3 x Rs.100, settled (FR-06, BR-05, BR-07)',
                CONCAT('fn_late_fee = ', fn_late_fee(v_bk2, NULL), ', balance ', v_amt, ', vehicle ', v_s));

  CALL rental_create_booking(1003, t3, 502, NULL, v_start, v_start + INTERVAL 2 DAY, 1200, 'CARD', v_id);
  CALL rental_cancel_booking(v_id, v_amt);
  SELECT status INTO v_s FROM booking WHERE booking_id = v_id;
  CALL t_result('TC11', v_amt = 1200 AND v_s = 'CANCELLED', 'Module',
                'rental_cancel_booking 20 days before pickup refunds 100% of advance (BR-06)',
                CONCAT('Advance 1200, refund ', v_amt, ', status ', v_s, ', net paid ', fn_total_paid(v_id)));

  CALL rental_create_booking(1005, t3, 502, NULL, NOW() + INTERVAL 5 HOUR,
                             NOW() + INTERVAL 5 HOUR + INTERVAL 2 DAY, 2000, 'UPI', v_id);
  CALL rental_cancel_booking(v_id, v_amt);
  CALL t_result('TC12', v_amt = 1000, 'Module',
                'rental_cancel_booking 5 hours before pickup refunds only 50% (BR-06)',
                CONCAT('Advance 2000, refund ', v_amt));

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    CALL rental_create_booking(1001, t1, 503, NULL, v_start + INTERVAL 5 DAY, v_start + INTERVAL 6 DAY, 0, NULL, v_id);
  END;
  CALL t_expect('TC13', 'Module', 'rental_create_booking refuses a booking made by a MECHANIC', 20033, v_errno, v_msg);

  -- ======================= TRIGGERS =======================
  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    CALL rental_create_booking(1011, t1, 502, NULL, v_start + INTERVAL 5 DAY, v_start + INTERVAL 6 DAY, 0, NULL, v_id);
  END;
  CALL t_expect('TC14', 'Trigger', 'trg_booking_before_insert blocks a 19-year-old customer (BR-01)', 20001, v_errno, v_msg);

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    CALL rental_create_booking(1012, t1, 502, NULL, NOW() + INTERVAL 1 DAY, NOW() + INTERVAL 8 DAY, 0, NULL, v_id);
  END;
  CALL t_expect('TC15', 'Trigger', 'trg_booking_before_insert blocks a licence that expires during the rental (BR-01)', 20002, v_errno, v_msg);

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    CALL rental_create_booking(1008, t1, 502, NULL, v_start + INTERVAL 1 DAY, v_start + INTERVAL 2 DAY, 0, NULL, v_id);
  END;
  CALL t_expect('TC16', 'Trigger', 'trg_booking_before_insert blocks a double booking of the TC07 vehicle (BR-02)', 20004, v_errno, v_msg);

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    CALL rental_create_booking(1003, t2, 502, NULL, v_start, v_start + INTERVAL 1 DAY, 0, NULL, v_id);
  END;
  CALL t_expect('TC17', 'Trigger', 'trg_booking_before_insert blocks a vehicle under MAINTENANCE (BR-03)', 20003, v_errno, v_msg);

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    UPDATE vehicle SET odometer = 50 WHERE vehicle_id = t1;
  END;
  CALL t_expect('TC18', 'Trigger', 'trg_vehicle_before_update stops an odometer from going backwards (BR-08)', 20006, v_errno, v_msg);

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    UPDATE booking SET status = 'BOOKED' WHERE booking_id = v_bk2;          -- v_bk2 is COMPLETED
  END;
  CALL t_expect('TC19', 'Trigger', 'trg_booking_before_update rejects COMPLETED -> BOOKED', 20005, v_errno, v_msg);

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    SELECT MIN(booking_id) INTO v_id FROM booking WHERE status = 'CANCELLED';
    CALL rental_add_payment(v_id, 500, 'CASH', 'FINAL', v_n);
  END;
  CALL t_expect('TC20', 'Trigger', 'trg_payment_before_insert rejects a FINAL payment on a cancelled booking', 20008, v_errno, v_msg);

  SELECT COUNT(*), GROUP_CONCAT(CONCAT(COALESCE(old_status, '-'), '>', new_status) ORDER BY audit_id SEPARATOR ', ')
    INTO v_n, v_s FROM booking_audit WHERE booking_id = v_bk2;
  CALL t_result('TC21', v_n = 3, 'Trigger', 'trg_booking_after_insert/update log every status change of the TC09/TC10 booking',
                CONCAT(v_n, ' audit rows: ', v_s));

  CALL fleet_schedule_maintenance(t3, 'REPAIR', 'Test: clutch noise', NOW(), v_id);
  SELECT status INTO v_s FROM vehicle WHERE vehicle_id = t3;
  CALL fleet_update_maintenance(v_id, 'DONE', 2500);
  SELECT CONCAT(v_s, ' -> ', status) INTO v_s FROM vehicle WHERE vehicle_id = t3;
  CALL t_result('TC22', v_s = 'MAINTENANCE -> AVAILABLE', 'Trigger',
                'trg_maint_after_insert/update: job opened -> vehicle MAINTENANCE, job DONE -> AVAILABLE (FR-09)',
                CONCAT('Vehicle ', t3, ' status ', v_s));

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    CALL fleet_schedule_maintenance(t5, 'GENERAL', 'Test', NOW(), v_id);
  END;
  CALL t_expect('TC23', 'Trigger', 'trg_maint_before_insert blocks maintenance on a RENTED vehicle', 20007, v_errno, v_msg);

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    CALL rental_record_return(v_bk5, 400, NOW() + INTERVAL 1 HOUR, NULL, v_amt);
  END;
  CALL t_expect('TC24', 'Module', 'rental_record_return rejects end odometer lower than start (BR-08)', 20051, v_errno, v_msg);

  SET v_errno = 0;
  BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    INSERT INTO customer (name, phone, license_no, license_expiry, dob)
    VALUES ('Expired Licence', '9000000009', 'TN99TEST0009', CURDATE() - INTERVAL 10 DAY, '1990-01-01');
  END;
  CALL t_expect('TC25', 'Trigger', 'trg_customer_before_insert rejects registration with an expired licence', 20013, v_errno, v_msg);

  -- ======================= CURSORS =======================
  SELECT COALESCE(MAX(maint_id), 0) INTO v_mark FROM maintenance;
  CALL fleet_auto_schedule_service(v_n);
  SELECT COUNT(*) INTO v_n2 FROM maintenance
   WHERE maint_id > v_mark AND description LIKE 'Auto:%' AND maint_status = 'SCHEDULED';
  CALL t_result('TC26', v_n > 0 AND v_n = v_n2, 'Cursor',
                'fleet_auto_schedule_service (explicit cursor OPEN/FETCH/CLOSE) schedules overdue services',
                CONCAT(v_n, ' service job(s) created for vehicles not serviced in 180 days'));

  -- explicit cursor over the pending-dues view used by report_pending_dues
  BEGIN
    DECLARE v_done INT DEFAULT 0;
    DECLARE c_bid  INT;
    DECLARE c_bal  DECIMAL(10,2);
    DECLARE c_dues CURSOR FOR
      SELECT booking_id, balance FROM v_booking_summary
       WHERE status IN ('BOOKED', 'ONGOING', 'COMPLETED') AND balance > 0;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
    SET v_n = 0; SET v_amt = 0;
    OPEN c_dues;
    dues_loop: LOOP
      FETCH c_dues INTO c_bid, c_bal;
      IF v_done = 1 THEN LEAVE dues_loop; END IF;
      SET v_n = v_n + 1;
      IF c_bid = v_bk5 THEN SET v_amt = c_bal; END IF;
    END LOOP;
    CLOSE c_dues;
  END;
  CALL t_result('TC27', v_amt = 3000, 'Cursor',
                'Cursor over pending dues (report_pending_dues) lists the unpaid test rental: 2 days x Rs.1500 (FR-11)',
                CONCAT(v_n, ' booking(s) with dues; booking ', v_bk5, ' owes Rs.', v_amt));

  SELECT COUNT(*) INTO v_n  FROM v_booking_summary WHERE customer_id = 1001;
  SELECT COUNT(*) INTO v_n2 FROM booking WHERE customer_id = 1001;
  CALL t_result('TC28', v_n = v_n2 AND v_n > 0, 'Cursor',
                'rental_customer_history returns every booking of customer 1001 (FR-12)',
                CONCAT(v_n, ' rows returned, ', v_n2, ' bookings in table'));

  -- leave the sample data untouched
  ROLLBACK TO SAVEPOINT test_start;
  IF v_prev_autocommit = 1 THEN ROLLBACK; SET autocommit = 1; END IF;

  -- (a MySQL temporary table cannot be opened twice in one query, so the
  --  totals are worked out first and added as the last row)
  SELECT SUM(result = 'PASS'), SUM(result = 'FAIL') INTO v_n, v_n2 FROM test_result;
  INSERT INTO test_result VALUES
    ('TOTAL', IF(v_n2 = 0, 'PASS', 'FAIL'), '',
     CONCAT(v_n, ' passed, ', v_n2, ' failed, ', v_n + v_n2, ' total'), 'All test changes rolled back');
  SELECT tc, result, area, test_case, actual_output FROM test_result;
  DROP TEMPORARY TABLE test_result;
END$$

DELIMITER ;

SELECT 'Test procedure created - run:  CALL run_all_tests();' AS status;
