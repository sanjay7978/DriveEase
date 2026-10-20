-- =====================================================================
-- DriveEase - 07_test_package.sql : automated TEST CASES (pkg_test)
-- Every test runs inside one transaction that is ROLLED BACK at the end,
-- so the sample data is never changed by testing.
--
-- Run in SQL Developer:   SET SERVEROUTPUT ON
--                         EXEC pkg_test.run_all;
-- Each result line:  TCnn | PASS/FAIL | area | test | actual result
-- =====================================================================
SET DEFINE OFF

CREATE OR REPLACE PACKAGE pkg_test AS
  PROCEDURE run_all;
END pkg_test;
/

CREATE OR REPLACE PACKAGE BODY pkg_test AS
  g_pass NUMBER;
  g_fail NUMBER;

  PROCEDURE result (p_tc VARCHAR2, p_ok BOOLEAN, p_area VARCHAR2, p_test VARCHAR2, p_actual VARCHAR2) IS
  BEGIN
    IF p_ok THEN g_pass := g_pass + 1; ELSE g_fail := g_fail + 1; END IF;
    DBMS_OUTPUT.PUT_LINE(p_tc || ' | ' || CASE WHEN p_ok THEN 'PASS' ELSE 'FAIL' END || ' | ' ||
                         p_area || ' | ' || p_test || ' | ' || SUBSTR(p_actual, 1, 250));
  END result;

  -- for negative tests: PASS when the expected ORA-xxxxx error was raised
  PROCEDURE expect_err (p_tc VARCHAR2, p_area VARCHAR2, p_test VARCHAR2,
                        p_code NUMBER, p_got NUMBER, p_msg VARCHAR2) IS
  BEGIN
    result(p_tc, p_got = p_code, p_area, p_test,
           CASE WHEN p_got = 0 THEN 'No error raised (expected ORA' || p_code || ')'
                ELSE 'Rejected with ' || REGEXP_SUBSTR(p_msg, '^[^' || CHR(10) || ']*') END);
  END expect_err;

  PROCEDURE unexpected (p_tc VARCHAR2, p_area VARCHAR2, p_test VARCHAR2) IS
  BEGIN
    result(p_tc, FALSE, p_area, p_test, 'Unexpected error: ' || SQLERRM);
  END unexpected;

  -- ===================================================================
  PROCEDURE run_all IS
    v_start DATE := TRUNC(SYSDATE) + 20 + 9/24;      -- a quiet future window for tests
    v_n     NUMBER;
    v_n2    NUMBER;
    v_s     VARCHAR2(200);
    v_id    NUMBER;
    v_bk    NUMBER;
    v_bk2   NUMBER;
    v_amt   NUMBER;
    v_err   NUMBER;
    v_msg   VARCHAR2(4000);
    v_end   DATE;
    v_rc    SYS_REFCURSOR;
    -- columns of pkg_rental.search_available
    v_vid NUMBER; v_reg VARCHAR2(20); v_brand VARCHAR2(30); v_model VARCHAR2(30);
    v_fuel VARCHAR2(10); v_trans VARCHAR2(10); v_cat VARCHAR2(30); v_rate NUMBER;
    v_seats NUMBER; v_bid NUMBER; v_bname VARCHAR2(50); v_city VARCHAR2(30); v_est NUMBER;
    -- private test vehicles, so results never depend on the state of the sample data
    t1 NUMBER; t2 NUMBER; t3 NUMBER; t4 NUMBER; t5 NUMBER; v_bk5 NUMBER; v_mark NUMBER;
  BEGIN
    g_pass := 0; g_fail := 0;
    SAVEPOINT pkg_test_start;
    DBMS_OUTPUT.PUT_LINE('DriveEase test run at ' || TO_CHAR(SYSDATE, 'DD-Mon-YYYY HH24:MI:SS'));

    -- ---------- set-up: own test vehicles (all rolled back at the end) ----------
    sp_add_vehicle('TST0001', 'Test', 'Hatch A', 2025, 'PETROL', 'MANUAL',  100, 1, 1, t1);
    sp_add_vehicle('TST0002', 'Test', 'Sedan',   2025, 'PETROL', 'MANUAL',  100, 2, 1, t2);
    sp_add_vehicle('TST0003', 'Test', 'SUV',     2025, 'DIESEL', 'MANUAL',  100, 3, 1, t3);
    sp_add_vehicle('TST0004', 'Test', 'Hatch B', 2025, 'PETROL', 'MANUAL', 1000, 1, 1, t4);
    sp_add_vehicle('TST0005', 'Test', 'Hatch C', 2025, 'PETROL', 'MANUAL',  500, 1, 1, t5);
    pkg_fleet.schedule_maintenance(t2, 'REPAIR', 'Test set-up', SYSDATE, v_id);       -- t2 under maintenance
    pkg_rental.create_booking(1001, t5, 502, NULL, SYSDATE + 1/24, SYSDATE + 1/24 + 2, 0, NULL, v_bk5);
    pkg_rental.record_pickup(v_bk5, 500);                                            -- t5 rented out
    DBMS_OUTPUT.PUT_LINE('SETUP | test vehicles ' || t1 || '-' || t5 || ' created; ' || t2 ||
                         ' in maintenance; ' || t5 || ' rented on booking ' || v_bk5);
    DBMS_OUTPUT.PUT_LINE('TC   | RESULT | AREA | TEST CASE | ACTUAL OUTPUT');

    -- ======================= FUNCTIONS =======================
    BEGIN
      v_n  := fn_customer_age(1001);
      v_n2 := TRUNC(MONTHS_BETWEEN(SYSDATE, DATE '1996-04-10') / 12);
      result('TC01', v_n = v_n2, 'Function', 'fn_customer_age(1001) derives age from DOB 10-Apr-1996',
             'Returned ' || v_n || ' (expected ' || v_n2 || ')');
    EXCEPTION WHEN OTHERS THEN unexpected('TC01', 'Function', 'fn_customer_age'); END;

    BEGIN
      v_s := fn_is_vehicle_available(t2, SYSDATE + 1, SYSDATE + 2) || '/' ||
             fn_is_vehicle_available(t1, v_start, v_start + 2);
      result('TC02', v_s = 'N/Y', 'Function', 'fn_is_vehicle_available: vehicle in MAINTENANCE -> N, free vehicle -> Y',
             'Returned ' || v_s);
    EXCEPTION WHEN OTHERS THEN unexpected('TC02', 'Function', 'fn_is_vehicle_available'); END;

    -- ======================= PROCEDURES =======================
    BEGIN
      sp_register_customer('Test Customer', '9000000001', 'test.customer@example.com', 'TN99TEST0001',
                           ADD_MONTHS(SYSDATE, 60), DATE '1998-01-01', 'Vellore', v_id);
      SELECT COUNT(*) INTO v_n FROM customer WHERE customer_id = v_id;
      result('TC03', v_n = 1, 'Procedure', 'sp_register_customer registers a valid customer (FR-01)',
             'Customer ' || v_id || ' created');
    EXCEPTION WHEN OTHERS THEN unexpected('TC03', 'Procedure', 'sp_register_customer'); END;

    v_err := 0;
    BEGIN
      sp_register_customer('Duplicate Licence', '9000000002', NULL, 'TN99TEST0001',
                           ADD_MONTHS(SYSDATE, 60), DATE '1998-01-01', NULL, v_id);
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC04', 'Procedure', 'sp_register_customer rejects a duplicate licence number', -20020, v_err, v_msg);

    BEGIN
      sp_add_vehicle('TN23ZZ9999', 'Maruti', 'Ertiga', 2025, 'CNG', 'MANUAL', 100, 3, 1, v_id);
      SELECT status INTO v_s FROM vehicle WHERE vehicle_id = v_id;
      result('TC05', v_s = 'AVAILABLE', 'Procedure', 'sp_add_vehicle adds a vehicle with default status AVAILABLE (FR-02)',
             'Vehicle ' || v_id || ' status ' || v_s);
    EXCEPTION WHEN OTHERS THEN unexpected('TC05', 'Procedure', 'sp_add_vehicle'); END;

    v_err := 0;
    BEGIN sp_retire_vehicle(t5); EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC06', 'Procedure', 'sp_retire_vehicle refuses a vehicle that has an open booking', -20024, v_err, v_msg);

    -- ======================= PACKAGE pkg_rental =======================
    BEGIN
      pkg_rental.create_booking(1007, t1, 502, NULL, v_start, v_start + 3, 1000, 'UPI', v_bk);
      SELECT COUNT(*) INTO v_n FROM payment WHERE booking_id = v_bk AND payment_type = 'ADVANCE';
      v_amt := fn_rental_amount(v_bk);
      result('TC07', v_n = 1 AND v_amt = 4500 AND fn_rental_days(v_bk) = 3, 'Package',
             'pkg_rental.create_booking: booking + advance in one transaction; rent = 3 days x Rs.1500 (BR-04)',
             'Booking ' || v_bk || ', advance rows ' || v_n || ', fn_rental_days ' || fn_rental_days(v_bk) ||
             ', fn_rental_amount ' || v_amt);
    EXCEPTION WHEN OTHERS THEN unexpected('TC07', 'Package', 'pkg_rental.create_booking'); END;

    BEGIN
      v_rc := pkg_rental.search_available(NULL, 1, v_start + 1, v_start + 2);
      v_n := 0; v_n2 := 0;
      LOOP
        FETCH v_rc INTO v_vid, v_reg, v_brand, v_model, v_fuel, v_trans, v_cat, v_rate, v_seats,
                        v_bid, v_bname, v_city, v_est;
        EXIT WHEN v_rc%NOTFOUND;
        v_n := v_n + 1;
        IF v_vid = t1 THEN v_n2 := 1; END IF;
      END LOOP;
      CLOSE v_rc;
      result('TC08', v_n > 0 AND v_n2 = 0, 'Cursor', 'pkg_rental.search_available (REF CURSOR) hides the vehicle booked in TC07 (FR-03)',
             v_n || ' hatchbacks free; vehicle ' || t1 || ' listed: ' || CASE v_n2 WHEN 1 THEN 'YES' ELSE 'NO' END);
    EXCEPTION WHEN OTHERS THEN unexpected('TC08', 'Cursor', 'pkg_rental.search_available'); END;

    BEGIN
      pkg_rental.create_booking(1002, t4, 502, 2, SYSDATE + 2/24, SYSDATE + 2/24 + 1, 500, 'CASH', v_bk2);
      pkg_rental.record_pickup(v_bk2, 1000);
      SELECT b.status || '/' || v.status INTO v_s
        FROM booking b JOIN vehicle v ON v.vehicle_id = b.vehicle_id WHERE b.booking_id = v_bk2;
      result('TC09', v_s = 'ONGOING/RENTED', 'Package', 'pkg_rental.record_pickup: booking -> ONGOING, vehicle -> RENTED (FR-05)',
             'Booking ' || v_bk2 || ' / vehicle ' || t4 || ' = ' || v_s);
    EXCEPTION WHEN OTHERS THEN unexpected('TC09', 'Package', 'pkg_rental.record_pickup'); END;

    BEGIN
      SELECT end_date INTO v_end FROM booking WHERE booking_id = v_bk2;
      v_n := fn_late_fee(v_bk2, v_end + 2.5/24);            -- "what-if" 2.5 h late -> 3 h charged
      pkg_rental.record_return(v_bk2, 1150, v_end + 3/24, 'UPI', v_amt);
      SELECT v.status || '/branch ' || v.branch_id || '/odo ' || v.odometer INTO v_s
        FROM vehicle v WHERE vehicle_id = t4;
      result('TC10', fn_late_fee(v_bk2) = 300 AND v_n = 300 AND v_amt = 0
                     AND v_s = 'AVAILABLE/branch 2/odo 1150', 'Package',
             'pkg_rental.record_return 3 h late, one-way to branch 2: late fee 3 x Rs.100, settled (FR-06, BR-05, BR-07)',
             'fn_late_fee = ' || fn_late_fee(v_bk2) || ', balance ' || v_amt || ', vehicle ' || v_s);
    EXCEPTION WHEN OTHERS THEN unexpected('TC10', 'Package', 'pkg_rental.record_return'); END;

    BEGIN
      pkg_rental.create_booking(1003, t3, 502, NULL, v_start, v_start + 2, 1200, 'CARD', v_id);
      pkg_rental.cancel_booking(v_id, v_amt);
      SELECT status INTO v_s FROM booking WHERE booking_id = v_id;
      result('TC11', v_amt = 1200 AND v_s = 'CANCELLED', 'Package',
             'pkg_rental.cancel_booking 20 days before pickup refunds 100% of advance (BR-06)',
             'Advance 1200, refund ' || v_amt || ', status ' || v_s || ', net paid ' || fn_total_paid(v_id));
    EXCEPTION WHEN OTHERS THEN unexpected('TC11', 'Package', 'pkg_rental.cancel_booking (early)'); END;

    BEGIN
      pkg_rental.create_booking(1005, t3, 502, NULL, SYSDATE + 5/24, SYSDATE + 5/24 + 2, 2000, 'UPI', v_id);
      pkg_rental.cancel_booking(v_id, v_amt);
      result('TC12', v_amt = 1000, 'Package',
             'pkg_rental.cancel_booking 5 hours before pickup refunds only 50% (BR-06)',
             'Advance 2000, refund ' || v_amt);
    EXCEPTION WHEN OTHERS THEN unexpected('TC12', 'Package', 'pkg_rental.cancel_booking (late)'); END;

    v_err := 0;
    BEGIN pkg_rental.create_booking(1001, 105, 503, NULL, v_start, v_start + 1, 0, NULL, v_id);
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC13', 'Package', 'pkg_rental.create_booking refuses a booking made by a MECHANIC', -20033, v_err, v_msg);

    -- ======================= TRIGGERS =======================
    v_err := 0;
    BEGIN pkg_rental.create_booking(1011, 116, 511, NULL, v_start, v_start + 1, 0, NULL, v_id);
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC14', 'Trigger', 'trg_booking_eligibility blocks a 19-year-old customer (BR-01)', -20001, v_err, v_msg);

    v_err := 0;
    BEGIN pkg_rental.create_booking(1012, 116, 511, NULL, SYSDATE + 1, SYSDATE + 8, 0, NULL, v_id);
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC15', 'Trigger', 'trg_booking_eligibility blocks a licence that expires during the rental (BR-01)', -20002, v_err, v_msg);

    v_err := 0;
    BEGIN pkg_rental.create_booking(1008, t1, 502, NULL, v_start + 1, v_start + 2, 0, NULL, v_id);
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC16', 'Trigger', 'trg_booking_no_overlap (compound) blocks a double booking of the TC07 vehicle (BR-02)', -20004, v_err, v_msg);

    v_err := 0;
    BEGIN pkg_rental.create_booking(1003, t2, 502, NULL, v_start, v_start + 1, 0, NULL, v_id);
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC17', 'Trigger', 'trg_booking_eligibility blocks a vehicle under MAINTENANCE (BR-03)', -20003, v_err, v_msg);

    v_err := 0;
    BEGIN UPDATE vehicle SET odometer = 50 WHERE vehicle_id = t1;
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC18', 'Trigger', 'trg_vehicle_odometer stops an odometer from going backwards (BR-08)', -20006, v_err, v_msg);

    v_err := 0;
    BEGIN
      SELECT MIN(booking_id) INTO v_id FROM booking WHERE status = 'COMPLETED';
      UPDATE booking SET status = 'BOOKED' WHERE booking_id = v_id;
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC19', 'Trigger', 'trg_booking_status_flow rejects COMPLETED -> BOOKED', -20005, v_err, v_msg);

    v_err := 0;
    BEGIN
      SELECT MIN(booking_id) INTO v_id FROM booking WHERE status = 'CANCELLED';
      pkg_rental.add_payment(v_id, 500, 'CASH', 'FINAL', v_n);
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC20', 'Trigger', 'trg_payment_validate rejects a FINAL payment on a cancelled booking', -20008, v_err, v_msg);

    BEGIN
      SELECT COUNT(*) INTO v_n FROM booking_audit WHERE booking_id = v_bk2;
      SELECT LISTAGG(NVL(old_status, '-') || '>' || new_status, ', ') WITHIN GROUP (ORDER BY audit_id)
        INTO v_s FROM booking_audit WHERE booking_id = v_bk2;
      result('TC21', v_n = 3, 'Trigger', 'trg_booking_audit logs every status change of booking from TC09/TC10',
             v_n || ' audit rows: ' || v_s);
    EXCEPTION WHEN OTHERS THEN unexpected('TC21', 'Trigger', 'trg_booking_audit'); END;

    BEGIN
      pkg_fleet.schedule_maintenance(t3, 'REPAIR', 'Test: clutch noise', SYSDATE, v_id);
      SELECT status INTO v_s FROM vehicle WHERE vehicle_id = t3;
      pkg_fleet.update_maintenance(v_id, 'DONE', 2500);
      SELECT v_s || ' -> ' || status INTO v_s FROM vehicle WHERE vehicle_id = t3;
      result('TC22', v_s = 'MAINTENANCE -> AVAILABLE', 'Trigger',
             'trg_maint_vehicle_status: job opened -> vehicle MAINTENANCE, job DONE -> AVAILABLE (FR-09)',
             'Vehicle ' || t3 || ' status ' || v_s);
    EXCEPTION WHEN OTHERS THEN unexpected('TC22', 'Trigger', 'trg_maint_vehicle_status'); END;

    v_err := 0;
    BEGIN pkg_fleet.schedule_maintenance(t5, 'GENERAL', 'Test', SYSDATE, v_id);
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC23', 'Trigger', 'trg_maint_before_insert blocks maintenance on a RENTED vehicle', -20007, v_err, v_msg);

    v_err := 0;
    BEGIN
      pkg_rental.record_return(v_bk5, 400, SYSDATE + 1/24, NULL, v_amt);
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC24', 'Package', 'pkg_rental.record_return rejects end odometer lower than start (BR-08)', -20051, v_err, v_msg);

    v_err := 0;
    BEGIN
      INSERT INTO customer (name, phone, license_no, license_expiry, dob)
      VALUES ('Expired Licence', '9000000009', 'TN99TEST0009', SYSDATE - 10, DATE '1990-01-01');
    EXCEPTION WHEN OTHERS THEN v_err := SQLCODE; v_msg := SQLERRM; END;
    expect_err('TC25', 'Trigger', 'trg_customer_validate rejects registration with an expired licence', -20013, v_err, v_msg);

    -- ======================= CURSORS =======================
    BEGIN
      SELECT NVL(MAX(maint_id), 0) INTO v_mark FROM maintenance;
      pkg_fleet.auto_schedule_service(v_n);
      SELECT COUNT(*) INTO v_n2 FROM maintenance
       WHERE maint_id > v_mark AND description LIKE 'Auto:%' AND maint_status = 'SCHEDULED';
      result('TC26', v_n > 0 AND v_n = v_n2, 'Cursor',
             'pkg_fleet.auto_schedule_service (explicit cursor OPEN/FETCH/CLOSE) schedules overdue services',
             v_n || ' service job(s) created for vehicles not serviced in 180 days');
    EXCEPTION WHEN OTHERS THEN unexpected('TC26', 'Cursor', 'pkg_fleet.auto_schedule_service'); END;

    BEGIN
      v_rc := pkg_reports.pending_dues;
      v_n := 0; v_n2 := 0;
      LOOP
        FETCH v_rc INTO v_id, v_s, v_reg, v_fuel, v_brand, v_end, v_amt, v_rate, v_est;
        EXIT WHEN v_rc%NOTFOUND;
        v_n := v_n + 1;
        IF v_id = v_bk5 THEN v_n2 := v_est; END IF;
      END LOOP;
      CLOSE v_rc;
      result('TC27', v_n2 = 3000, 'Cursor', 'pkg_reports.pending_dues (REF CURSOR) lists the unpaid test rental: 2 days x Rs.1500 (FR-11)',
             v_n || ' booking(s) with dues; booking ' || v_bk5 || ' owes Rs.' || v_n2);
    EXCEPTION WHEN OTHERS THEN unexpected('TC27', 'Cursor', 'pkg_reports.pending_dues'); END;

    BEGIN
      v_rc := pkg_rental.customer_history(1001);
      v_n := 0;
      LOOP
        FETCH v_rc INTO v_id, v_s, v_end, v_end, v_end, v_reg, v_msg, v_bname, v_city, v_amt, v_rate, v_est, v_seats;
        EXIT WHEN v_rc%NOTFOUND;
        v_n := v_n + 1;
      END LOOP;
      CLOSE v_rc;
      SELECT COUNT(*) INTO v_n2 FROM booking WHERE customer_id = 1001;
      result('TC28', v_n = v_n2, 'Cursor', 'pkg_rental.customer_history returns every booking of customer 1001 (FR-12)',
             v_n || ' rows fetched, ' || v_n2 || ' bookings in table');
    EXCEPTION WHEN OTHERS THEN unexpected('TC28', 'Cursor', 'pkg_rental.customer_history'); END;

    ROLLBACK TO pkg_test_start;                -- leave the sample data untouched
    DBMS_OUTPUT.PUT_LINE('SUMMARY | ' || g_pass || ' passed | ' || g_fail || ' failed | ' ||
                         (g_pass + g_fail) || ' total | all test changes rolled back');
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO pkg_test_start;
      DBMS_OUTPUT.PUT_LINE('ERROR | test run aborted: ' || SQLERRM);
  END run_all;
END pkg_test;
/

PROMPT Test package created.
