-- =====================================================================
-- DriveEase - 08_demo_queries.sql
-- Open in SQL Developer (connection DRIVEEASE) and press F5 (Run Script).
-- Shows every PL/SQL object working - use for output screenshots.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100

PROMPT ===== 1. AUTOMATED TEST CASES (28 tests, changes rolled back) =====
EXEC pkg_test.run_all;

PROMPT ===== 2. FUNCTIONS used inside SQL =====
SELECT customer_id, name, dob, fn_customer_age(customer_id) AS age
  FROM customer ORDER BY customer_id;

SELECT booking_id, status,
       fn_rental_days(booking_id)   AS days,
       fn_rental_amount(booking_id) AS rent,
       fn_late_fee(booking_id)      AS late_fee,
       fn_total_paid(booking_id)    AS paid,
       fn_balance_due(booking_id)   AS balance
  FROM booking ORDER BY booking_id;

PROMPT ===== 3. EXPLICIT CURSORS printed with DBMS_OUTPUT =====
EXEC pkg_rental.print_customer_history(1001);
EXEC pkg_reports.print_branch_summary;

PROMPT ===== 4. REF CURSOR reports (FR-11) =====
VARIABLE rc REFCURSOR
EXEC :rc := pkg_reports.branch_revenue(6);
PRINT rc
EXEC :rc := pkg_reports.fleet_utilisation(30);
PRINT rc
EXEC :rc := pkg_reports.top_customers(5);
PRINT rc
EXEC :rc := pkg_reports.pending_dues;
PRINT rc

PROMPT ===== 5. A full rental life-cycle by hand (then rolled back) =====
DECLARE
  v_bk   NUMBER;
  v_due  NUMBER;
  v_ref  NUMBER;
BEGIN
  pkg_rental.create_booking(p_customer_id => 1007, p_vehicle_id => 113, p_emp_id => 511,
                            p_return_branch_id => NULL,
                            p_start => SYSDATE + 1/24, p_end => SYSDATE + 1/24 + 2,
                            p_advance => 1000, p_method => 'UPI', p_booking_id => v_bk);
  DBMS_OUTPUT.PUT_LINE('Created booking ' || v_bk || ', rent ' || fn_rental_amount(v_bk) ||
                       ', paid ' || fn_total_paid(v_bk));
  pkg_rental.record_pickup(v_bk, 33000);
  DBMS_OUTPUT.PUT_LINE('Picked up. Balance ' || fn_balance_due(v_bk));
  pkg_rental.record_return(v_bk, 33420, SYSDATE + 1/24 + 2 + 4/24, 'CASH', v_due);
  DBMS_OUTPUT.PUT_LINE('Returned 4 h late. Late fee ' || fn_late_fee(v_bk) ||
                       ', balance after settlement ' || v_due);
  ROLLBACK;
END;
/

PROMPT ===== 6. Trigger in action: try to book a vehicle under maintenance =====
DECLARE
  v_bk NUMBER;
BEGIN
  pkg_rental.create_booking(1003, 112, 508, NULL, SYSDATE + 1, SYSDATE + 2, 0, NULL, v_bk);
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Blocked by trigger -> ' || SQLERRM);
END;
/

PROMPT ===== 7. Audit trail written by trg_booking_audit =====
SELECT * FROM booking_audit WHERE ROWNUM <= 15 ORDER BY audit_id DESC;
