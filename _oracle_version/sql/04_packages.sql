-- =====================================================================
-- DriveEase - 04_packages.sql : PACKAGES (spec + body)
--   pkg_rental  : booking life-cycle (FR-03..FR-08, FR-12)
--   pkg_fleet   : maintenance (FR-09)
--   pkg_reports : management reports with CURSORS (FR-11)
-- =====================================================================
SET DEFINE OFF

-- =====================================================================
-- PACKAGE pkg_rental
-- =====================================================================
CREATE OR REPLACE PACKAGE pkg_rental AS
  -- Cancellation within this many hours of pickup refunds only 50% (BR-06)
  c_full_refund_hours CONSTANT NUMBER := 24;

  -- FR-03 : vehicles free in a city/category for a date range
  FUNCTION search_available (
    p_city        IN VARCHAR2,
    p_category_id IN NUMBER,
    p_start       IN DATE,
    p_end         IN DATE
  ) RETURN SYS_REFCURSOR;

  -- FR-04 : create booking + advance payment in one transaction
  PROCEDURE create_booking (
    p_customer_id      IN  booking.customer_id%TYPE,
    p_vehicle_id       IN  booking.vehicle_id%TYPE,
    p_emp_id           IN  booking.emp_id%TYPE,
    p_return_branch_id IN  booking.return_branch_id%TYPE,
    p_start            IN  DATE,
    p_end              IN  DATE,
    p_advance          IN  NUMBER,
    p_method           IN  payment.method%TYPE,
    p_booking_id       OUT booking.booking_id%TYPE
  );

  -- FR-05 : pickup
  PROCEDURE record_pickup (
    p_booking_id     IN booking.booking_id%TYPE,
    p_start_odometer IN booking.start_odometer%TYPE
  );

  -- FR-06 : return, rent + late fee, one-way transfer, optional settlement
  PROCEDURE record_return (
    p_booking_id   IN  booking.booking_id%TYPE,
    p_end_odometer IN  booking.end_odometer%TYPE,
    p_return_date  IN  DATE DEFAULT SYSDATE,
    p_method       IN  payment.method%TYPE DEFAULT NULL,
    p_amount_due   OUT NUMBER
  );

  -- FR-08 : cancel + refund rule
  PROCEDURE cancel_booking (
    p_booking_id IN  booking.booking_id%TYPE,
    p_refund     OUT NUMBER
  );

  -- FR-07 : record a payment
  PROCEDURE add_payment (
    p_booking_id   IN  payment.booking_id%TYPE,
    p_amount       IN  payment.amount%TYPE,
    p_method       IN  payment.method%TYPE,
    p_payment_type IN  payment.payment_type%TYPE,
    p_payment_id   OUT payment.payment_id%TYPE
  );

  -- FR-12 : customer history (ref cursor for the web app)
  FUNCTION customer_history (p_customer_id IN NUMBER) RETURN SYS_REFCURSOR;

  -- FR-12 : the same history printed with an explicit cursor (SQL Developer)
  PROCEDURE print_customer_history (p_customer_id IN NUMBER);
END pkg_rental;
/

CREATE OR REPLACE PACKAGE BODY pkg_rental AS

  -- private helper: lock and fetch a booking row
  FUNCTION get_booking (p_booking_id IN NUMBER) RETURN booking%ROWTYPE IS
    r booking%ROWTYPE;
  BEGIN
    SELECT * INTO r FROM booking WHERE booking_id = p_booking_id FOR UPDATE;
    RETURN r;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20101, 'Booking ' || p_booking_id || ' does not exist');
  END get_booking;

  -- -------------------------------------------------------------------
  FUNCTION search_available (
    p_city        IN VARCHAR2,
    p_category_id IN NUMBER,
    p_start       IN DATE,
    p_end         IN DATE
  ) RETURN SYS_REFCURSOR
  IS
    rc SYS_REFCURSOR;
  BEGIN
    IF p_end <= p_start THEN
      RAISE_APPLICATION_ERROR(-20030, 'End date must be after start date');
    END IF;

    OPEN rc FOR
      SELECT v.vehicle_id, v.reg_number, v.brand, v.model, v.fuel_type, v.transmission,
             c.category_name, c.daily_rate, c.seating_capacity,
             b.branch_id, b.branch_name, b.city,
             GREATEST(1, CEIL(ROUND(p_end - p_start, 6))) * c.daily_rate AS estimated_rent
        FROM vehicle v
        JOIN vehicle_category c ON c.category_id = v.category_id
        JOIN branch b           ON b.branch_id   = v.branch_id
       WHERE (p_city IS NULL OR UPPER(b.city) = UPPER(p_city))
         AND (p_category_id IS NULL OR v.category_id = p_category_id)
         AND fn_is_vehicle_available(v.vehicle_id, p_start, p_end) = 'Y'
       ORDER BY c.daily_rate, v.vehicle_id;
    RETURN rc;
  END search_available;

  -- -------------------------------------------------------------------
  PROCEDURE create_booking (
    p_customer_id      IN  booking.customer_id%TYPE,
    p_vehicle_id       IN  booking.vehicle_id%TYPE,
    p_emp_id           IN  booking.emp_id%TYPE,
    p_return_branch_id IN  booking.return_branch_id%TYPE,
    p_start            IN  DATE,
    p_end              IN  DATE,
    p_advance          IN  NUMBER,
    p_method           IN  payment.method%TYPE,
    p_booking_id       OUT booking.booking_id%TYPE
  )
  IS
    v_branch  vehicle.branch_id%TYPE;
    v_role    employee.role%TYPE;
    v_pay_id  payment.payment_id%TYPE;
  BEGIN
    SAVEPOINT create_booking;

    IF p_start < SYSDATE - 1/24 THEN
      RAISE_APPLICATION_ERROR(-20031, 'Start date cannot be in the past');
    END IF;

    BEGIN
      SELECT role INTO v_role FROM employee WHERE emp_id = p_emp_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20032, 'Employee ' || p_emp_id || ' does not exist');
    END;
    IF v_role NOT IN ('AGENT', 'MANAGER') THEN
      RAISE_APPLICATION_ERROR(-20033, 'Only an AGENT or MANAGER can create bookings (employee is ' || v_role || ')');
    END IF;

    BEGIN
      SELECT branch_id INTO v_branch FROM vehicle WHERE vehicle_id = p_vehicle_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20034, 'Vehicle ' || p_vehicle_id || ' does not exist');
    END;

    -- the vehicle is picked up from its current home branch;
    -- age, licence, status and overlap rules are enforced by triggers
    INSERT INTO booking (customer_id, vehicle_id, emp_id, pickup_branch_id,
                         return_branch_id, start_date, end_date, status)
    VALUES (p_customer_id, p_vehicle_id, p_emp_id, v_branch,
            NVL(p_return_branch_id, v_branch), p_start, p_end, 'BOOKED')
    RETURNING booking_id INTO p_booking_id;

    IF NVL(p_advance, 0) > 0 THEN
      add_payment(p_booking_id, p_advance, NVL(p_method, 'CASH'), 'ADVANCE', v_pay_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO create_booking;
      RAISE;
  END create_booking;

  -- -------------------------------------------------------------------
  PROCEDURE record_pickup (
    p_booking_id     IN booking.booking_id%TYPE,
    p_start_odometer IN booking.start_odometer%TYPE
  )
  IS
    r        booking%ROWTYPE;
    v_odo    vehicle.odometer%TYPE;
    v_status vehicle.status%TYPE;
  BEGIN
    SAVEPOINT record_pickup;
    r := get_booking(p_booking_id);

    IF r.status <> 'BOOKED' THEN
      RAISE_APPLICATION_ERROR(-20040, 'Only a BOOKED booking can be picked up (status is ' || r.status || ')');
    END IF;
    IF SYSDATE < r.start_date - 1 THEN
      RAISE_APPLICATION_ERROR(-20041, 'Pickup is allowed at most 1 day before the start date');
    END IF;

    SELECT odometer, status INTO v_odo, v_status
      FROM vehicle WHERE vehicle_id = r.vehicle_id FOR UPDATE;
    IF v_status <> 'AVAILABLE' THEN
      RAISE_APPLICATION_ERROR(-20042, 'Vehicle is ' || v_status || ' and cannot be handed over');
    END IF;
    IF p_start_odometer < v_odo THEN
      RAISE_APPLICATION_ERROR(-20043, 'Start odometer (' || p_start_odometer ||
                                      ') is lower than the vehicle odometer (' || v_odo || ')');
    END IF;

    UPDATE booking
       SET status = 'ONGOING', start_odometer = p_start_odometer
     WHERE booking_id = p_booking_id;

    UPDATE vehicle
       SET status = 'RENTED', odometer = p_start_odometer
     WHERE vehicle_id = r.vehicle_id;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO record_pickup;
      RAISE;
  END record_pickup;

  -- -------------------------------------------------------------------
  PROCEDURE record_return (
    p_booking_id   IN  booking.booking_id%TYPE,
    p_end_odometer IN  booking.end_odometer%TYPE,
    p_return_date  IN  DATE DEFAULT SYSDATE,
    p_method       IN  payment.method%TYPE DEFAULT NULL,
    p_amount_due   OUT NUMBER
  )
  IS
    r          booking%ROWTYPE;
    v_rent     NUMBER;
    v_late     NUMBER;
    v_paid     NUMBER;
    v_rent_due NUMBER;
    v_pay_id   payment.payment_id%TYPE;
  BEGIN
    SAVEPOINT record_return;
    r := get_booking(p_booking_id);

    IF r.status <> 'ONGOING' THEN
      RAISE_APPLICATION_ERROR(-20050, 'Only an ONGOING booking can be returned (status is ' || r.status || ')');
    END IF;
    IF p_end_odometer < r.start_odometer THEN                       -- BR-08
      RAISE_APPLICATION_ERROR(-20051, 'End odometer (' || p_end_odometer ||
                                      ') cannot be lower than start odometer (' || r.start_odometer || ')');
    END IF;

    UPDATE booking
       SET status             = 'COMPLETED',
           end_odometer       = p_end_odometer,
           actual_return_date = NVL(p_return_date, SYSDATE)
     WHERE booking_id = p_booking_id;

    -- vehicle is free again and now belongs to the return branch (BR-07)
    UPDATE vehicle
       SET status    = 'AVAILABLE',
           odometer  = p_end_odometer,
           branch_id = r.return_branch_id
     WHERE vehicle_id = r.vehicle_id;

    v_rent := fn_rental_amount(p_booking_id);                       -- BR-04
    v_late := fn_late_fee(p_booking_id);                            -- BR-05
    v_paid := fn_total_paid(p_booking_id);
    p_amount_due := GREATEST(0, v_rent + v_late - v_paid);

    -- optional settlement at the counter
    IF p_method IS NOT NULL AND p_amount_due > 0 THEN
      v_rent_due := GREATEST(0, v_rent - v_paid);
      IF v_rent_due > 0 THEN
        add_payment(p_booking_id, v_rent_due, p_method, 'FINAL', v_pay_id);
      END IF;
      IF p_amount_due - v_rent_due > 0 THEN
        add_payment(p_booking_id, p_amount_due - v_rent_due, p_method, 'LATE_FEE', v_pay_id);
      END IF;
      p_amount_due := fn_balance_due(p_booking_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO record_return;
      RAISE;
  END record_return;

  -- -------------------------------------------------------------------
  PROCEDURE cancel_booking (
    p_booking_id IN  booking.booking_id%TYPE,
    p_refund     OUT NUMBER
  )
  IS
    r         booking%ROWTYPE;
    v_advance NUMBER;
    v_method  payment.method%TYPE;
    v_pay_id  payment.payment_id%TYPE;
  BEGIN
    SAVEPOINT cancel_booking;
    r := get_booking(p_booking_id);

    IF r.status <> 'BOOKED' THEN
      RAISE_APPLICATION_ERROR(-20060, 'Only a BOOKED booking can be cancelled (status is ' || r.status || ')');
    END IF;

    SELECT NVL(SUM(amount), 0), MAX(method)
      INTO v_advance, v_method
      FROM payment
     WHERE booking_id = p_booking_id
       AND payment_type = 'ADVANCE'
       AND txn_status = 'SUCCESS';

    -- BR-06: >= 24 h before pickup -> full refund, otherwise 50 %
    IF (r.start_date - SYSDATE) * 24 >= c_full_refund_hours THEN
      p_refund := v_advance;
    ELSE
      p_refund := ROUND(v_advance * 0.5, 2);
    END IF;

    UPDATE booking SET status = 'CANCELLED' WHERE booking_id = p_booking_id;

    IF p_refund > 0 THEN
      add_payment(p_booking_id, p_refund, v_method, 'REFUND', v_pay_id);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO cancel_booking;
      RAISE;
  END cancel_booking;

  -- -------------------------------------------------------------------
  PROCEDURE add_payment (
    p_booking_id   IN  payment.booking_id%TYPE,
    p_amount       IN  payment.amount%TYPE,
    p_method       IN  payment.method%TYPE,
    p_payment_type IN  payment.payment_type%TYPE,
    p_payment_id   OUT payment.payment_id%TYPE
  )
  IS
    v_status booking.status%TYPE;
  BEGIN
    SELECT status INTO v_status FROM booking WHERE booking_id = p_booking_id;

    IF UPPER(p_payment_type) = 'ADVANCE' AND v_status <> 'BOOKED' THEN
      RAISE_APPLICATION_ERROR(-20070, 'An ADVANCE can only be paid while the booking is BOOKED');
    END IF;
    IF UPPER(p_payment_type) = 'REFUND' AND p_amount > fn_total_paid(p_booking_id) THEN
      RAISE_APPLICATION_ERROR(-20071, 'Refund cannot exceed the amount paid (' ||
                                      fn_total_paid(p_booking_id) || ')');
    END IF;

    INSERT INTO payment (booking_id, amount, method, payment_type)
    VALUES (p_booking_id, p_amount, UPPER(p_method), UPPER(p_payment_type))
    RETURNING payment_id INTO p_payment_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20101, 'Booking ' || p_booking_id || ' does not exist');
  END add_payment;

  -- -------------------------------------------------------------------
  FUNCTION customer_history (p_customer_id IN NUMBER) RETURN SYS_REFCURSOR
  IS
    rc SYS_REFCURSOR;
  BEGIN
    OPEN rc FOR
      SELECT b.booking_id, b.status, b.start_date, b.end_date, b.actual_return_date,
             v.reg_number, v.brand || ' ' || v.model AS vehicle,
             pb.branch_name AS pickup_branch, rb.branch_name AS return_branch,
             fn_rental_amount(b.booking_id) AS rent,
             fn_late_fee(b.booking_id)      AS late_fee,
             fn_total_paid(b.booking_id)    AS paid,
             fn_balance_due(b.booking_id)   AS balance
        FROM booking b
        JOIN vehicle v  ON v.vehicle_id  = b.vehicle_id
        JOIN branch pb  ON pb.branch_id  = b.pickup_branch_id
        JOIN branch rb  ON rb.branch_id  = b.return_branch_id
       WHERE b.customer_id = p_customer_id
       ORDER BY b.start_date DESC;
    RETURN rc;
  END customer_history;

  -- -------------------------------------------------------------------
  -- Explicit cursors: parameterised cursor + nested cursor FOR loop
  PROCEDURE print_customer_history (p_customer_id IN NUMBER)
  IS
    CURSOR c_bookings (cp_cust NUMBER) IS
      SELECT b.booking_id, b.status, b.start_date, b.end_date,
             v.reg_number, v.brand || ' ' || v.model AS vehicle
        FROM booking b JOIN vehicle v ON v.vehicle_id = b.vehicle_id
       WHERE b.customer_id = cp_cust
       ORDER BY b.start_date;

    CURSOR c_payments (cp_booking NUMBER) IS
      SELECT payment_id, payment_type, method, amount, payment_date
        FROM payment WHERE booking_id = cp_booking ORDER BY payment_date;

    r_bk    c_bookings%ROWTYPE;
    v_name  customer.name%TYPE;
  BEGIN
    SELECT name INTO v_name FROM customer WHERE customer_id = p_customer_id;
    DBMS_OUTPUT.PUT_LINE('Rental history of ' || v_name || ' (customer ' || p_customer_id ||
                         ', age ' || fn_customer_age(p_customer_id) || ')');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));

    OPEN c_bookings(p_customer_id);
    LOOP
      FETCH c_bookings INTO r_bk;
      EXIT WHEN c_bookings%NOTFOUND;
      DBMS_OUTPUT.PUT_LINE('Booking ' || r_bk.booking_id || '  ' || RPAD(r_bk.status, 10) ||
                           TO_CHAR(r_bk.start_date, 'DD-Mon-YY') || ' -> ' ||
                           TO_CHAR(r_bk.end_date, 'DD-Mon-YY') || '  ' ||
                           r_bk.vehicle || ' (' || r_bk.reg_number || ')');
      DBMS_OUTPUT.PUT_LINE('    rent ' || fn_rental_amount(r_bk.booking_id) ||
                           ', late fee ' || fn_late_fee(r_bk.booking_id) ||
                           ', paid ' || fn_total_paid(r_bk.booking_id) ||
                           ', balance ' || fn_balance_due(r_bk.booking_id));
      FOR p IN c_payments(r_bk.booking_id) LOOP
        DBMS_OUTPUT.PUT_LINE('      - payment ' || p.payment_id || ' ' || RPAD(p.payment_type, 9) ||
                             RPAD(p.method, 11) || TO_CHAR(p.amount, '99,99,990.00'));
      END LOOP;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 70, '-'));
    DBMS_OUTPUT.PUT_LINE(c_bookings%ROWCOUNT || ' booking(s) found.');
    CLOSE c_bookings;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20100, 'Customer ' || p_customer_id || ' does not exist');
  END print_customer_history;

END pkg_rental;
/

-- =====================================================================
-- PACKAGE pkg_fleet  (FR-09)
-- =====================================================================
CREATE OR REPLACE PACKAGE pkg_fleet AS
  c_service_interval_days CONSTANT NUMBER := 180;

  PROCEDURE schedule_maintenance (
    p_vehicle_id   IN  maintenance.vehicle_id%TYPE,
    p_service_type IN  maintenance.service_type%TYPE,
    p_description  IN  maintenance.description%TYPE,
    p_service_date IN  DATE DEFAULT SYSDATE,
    p_maint_id     OUT maintenance.maint_id%TYPE
  );

  PROCEDURE update_maintenance (
    p_maint_id IN maintenance.maint_id%TYPE,
    p_status   IN maintenance.maint_status%TYPE,
    p_cost     IN maintenance.cost%TYPE DEFAULT NULL
  );

  -- cursor-driven batch job: schedules a GENERAL service for every
  -- available vehicle not serviced in the last 180 days
  PROCEDURE auto_schedule_service (p_jobs_created OUT NUMBER);
END pkg_fleet;
/

CREATE OR REPLACE PACKAGE BODY pkg_fleet AS

  PROCEDURE schedule_maintenance (
    p_vehicle_id   IN  maintenance.vehicle_id%TYPE,
    p_service_type IN  maintenance.service_type%TYPE,
    p_description  IN  maintenance.description%TYPE,
    p_service_date IN  DATE DEFAULT SYSDATE,
    p_maint_id     OUT maintenance.maint_id%TYPE
  )
  IS
    v_open NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_open
      FROM maintenance
     WHERE vehicle_id = p_vehicle_id
       AND maint_status IN ('SCHEDULED', 'IN_PROGRESS');
    IF v_open > 0 THEN
      RAISE_APPLICATION_ERROR(-20080, 'Vehicle ' || p_vehicle_id || ' already has an open maintenance job');
    END IF;

    -- trigger trg_maint_before_insert blocks rented / retired vehicles and
    -- trigger trg_maint_vehicle_status moves the vehicle to MAINTENANCE
    INSERT INTO maintenance (vehicle_id, service_date, service_type, description, maint_status)
    VALUES (p_vehicle_id, NVL(p_service_date, SYSDATE), UPPER(p_service_type),
            p_description, 'SCHEDULED')
    RETURNING maint_id INTO p_maint_id;
  END schedule_maintenance;

  PROCEDURE update_maintenance (
    p_maint_id IN maintenance.maint_id%TYPE,
    p_status   IN maintenance.maint_status%TYPE,
    p_cost     IN maintenance.cost%TYPE DEFAULT NULL
  )
  IS
    v_old maintenance.maint_status%TYPE;
  BEGIN
    SELECT maint_status INTO v_old FROM maintenance WHERE maint_id = p_maint_id FOR UPDATE;
    IF v_old = 'DONE' THEN
      RAISE_APPLICATION_ERROR(-20081, 'Maintenance job ' || p_maint_id || ' is already closed');
    END IF;

    UPDATE maintenance
       SET maint_status = UPPER(p_status),
           cost         = NVL(p_cost, cost)
     WHERE maint_id = p_maint_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20082, 'Maintenance job ' || p_maint_id || ' does not exist');
  END update_maintenance;

  -- Explicit cursor with OPEN / FETCH / EXIT WHEN %NOTFOUND / CLOSE
  PROCEDURE auto_schedule_service (p_jobs_created OUT NUMBER)
  IS
    CURSOR c_due IS
      SELECT v.vehicle_id, v.reg_number,
             (SELECT MAX(m.service_date) FROM maintenance m
               WHERE m.vehicle_id = v.vehicle_id
                 AND m.service_type = 'GENERAL'
                 AND m.maint_status = 'DONE') AS last_service
        FROM vehicle v
       WHERE v.status = 'AVAILABLE'
         AND NOT EXISTS (SELECT 1 FROM maintenance m
                          WHERE m.vehicle_id = v.vehicle_id
                            AND m.maint_status IN ('SCHEDULED', 'IN_PROGRESS'))
         AND NOT EXISTS (SELECT 1 FROM booking b             -- skip vehicles booked in the next 3 days
                          WHERE b.vehicle_id = v.vehicle_id
                            AND b.status = 'BOOKED'
                            AND b.start_date < SYSDATE + 3);
    r        c_due%ROWTYPE;
    v_id     maintenance.maint_id%TYPE;
  BEGIN
    p_jobs_created := 0;
    OPEN c_due;
    LOOP
      FETCH c_due INTO r;
      EXIT WHEN c_due%NOTFOUND;
      IF r.last_service IS NULL OR r.last_service < SYSDATE - c_service_interval_days THEN
        schedule_maintenance(r.vehicle_id, 'GENERAL',
                             'Auto: periodic service (last ' ||
                             NVL(TO_CHAR(r.last_service, 'DD-Mon-YYYY'), 'never') || ')',
                             TRUNC(SYSDATE) + 1, v_id);
        p_jobs_created := p_jobs_created + 1;
        DBMS_OUTPUT.PUT_LINE('Scheduled job ' || v_id || ' for ' || r.reg_number);
      END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(c_due%ROWCOUNT || ' vehicle(s) checked, ' || p_jobs_created || ' job(s) created.');
    CLOSE c_due;
  END auto_schedule_service;

END pkg_fleet;
/

-- =====================================================================
-- PACKAGE pkg_reports  (FR-11)
-- =====================================================================
CREATE OR REPLACE PACKAGE pkg_reports AS
  FUNCTION branch_revenue (p_months IN NUMBER DEFAULT 6) RETURN SYS_REFCURSOR;
  FUNCTION fleet_utilisation (p_days IN NUMBER DEFAULT 30) RETURN SYS_REFCURSOR;
  FUNCTION top_customers (p_limit IN NUMBER DEFAULT 5) RETURN SYS_REFCURSOR;
  FUNCTION pending_dues RETURN SYS_REFCURSOR;

  -- prints a branch-wise summary using nested explicit cursors
  PROCEDURE print_branch_summary;
END pkg_reports;
/

CREATE OR REPLACE PACKAGE BODY pkg_reports AS

  -- Monthly revenue per pickup branch (refunds counted as negative)
  FUNCTION branch_revenue (p_months IN NUMBER DEFAULT 6) RETURN SYS_REFCURSOR
  IS
    rc SYS_REFCURSOR;
  BEGIN
    OPEN rc FOR
      SELECT br.branch_name,
             TO_CHAR(TRUNC(p.payment_date, 'MM'), 'YYYY-MM') AS month,
             SUM(CASE WHEN p.payment_type = 'REFUND' THEN -p.amount ELSE p.amount END) AS revenue,
             COUNT(DISTINCT p.booking_id) AS bookings
        FROM payment p
        JOIN booking b ON b.booking_id = p.booking_id
        JOIN branch br ON br.branch_id = b.pickup_branch_id
       WHERE p.txn_status = 'SUCCESS'
         AND p.payment_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -(p_months - 1))
       GROUP BY br.branch_name, TRUNC(p.payment_date, 'MM')
       ORDER BY month DESC, revenue DESC;
    RETURN rc;
  END branch_revenue;

  -- % of the last p_days each vehicle spent on rent
  FUNCTION fleet_utilisation (p_days IN NUMBER DEFAULT 30) RETURN SYS_REFCURSOR
  IS
    rc SYS_REFCURSOR;
  BEGIN
    OPEN rc FOR
      SELECT v.vehicle_id, v.reg_number, v.brand || ' ' || v.model AS vehicle,
             c.category_name, br.branch_name, v.status,
             ROUND(NVL(SUM(GREATEST(0,
                     LEAST(NVL(b.actual_return_date, SYSDATE), SYSDATE)
                   - GREATEST(b.start_date, SYSDATE - p_days))), 0), 1) AS days_rented,
             ROUND(100 * NVL(SUM(GREATEST(0,
                     LEAST(NVL(b.actual_return_date, SYSDATE), SYSDATE)
                   - GREATEST(b.start_date, SYSDATE - p_days))), 0) / p_days, 1) AS utilisation_pct
        FROM vehicle v
        JOIN vehicle_category c ON c.category_id = v.category_id
        JOIN branch br          ON br.branch_id  = v.branch_id
        LEFT JOIN booking b     ON b.vehicle_id  = v.vehicle_id
                               AND b.status IN ('ONGOING', 'COMPLETED')
       WHERE v.status <> 'RETIRED'
       GROUP BY v.vehicle_id, v.reg_number, v.brand, v.model, c.category_name,
                br.branch_name, v.status
       ORDER BY utilisation_pct DESC, v.vehicle_id;
    RETURN rc;
  END fleet_utilisation;

  FUNCTION top_customers (p_limit IN NUMBER DEFAULT 5) RETURN SYS_REFCURSOR
  IS
    rc SYS_REFCURSOR;
  BEGIN
    OPEN rc FOR
      SELECT * FROM (
        SELECT cu.customer_id, cu.name, cu.phone,
               COUNT(DISTINCT b.booking_id) AS rentals,
               NVL(SUM(fn_total_paid(b.booking_id)), 0) AS total_spent
          FROM customer cu
          JOIN booking b ON b.customer_id = cu.customer_id
         WHERE b.status IN ('ONGOING', 'COMPLETED')
         GROUP BY cu.customer_id, cu.name, cu.phone
         ORDER BY rentals DESC, total_spent DESC
      ) WHERE ROWNUM <= p_limit;
    RETURN rc;
  END top_customers;

  FUNCTION pending_dues RETURN SYS_REFCURSOR
  IS
    rc SYS_REFCURSOR;
  BEGIN
    OPEN rc FOR
      SELECT * FROM (
        SELECT b.booking_id, cu.name AS customer, cu.phone, b.status,
               v.reg_number, b.end_date,
               fn_rental_amount(b.booking_id) + fn_late_fee(b.booking_id) AS total_charge,
               fn_total_paid(b.booking_id)  AS paid,
               fn_balance_due(b.booking_id) AS balance
          FROM booking b
          JOIN customer cu ON cu.customer_id = b.customer_id
          JOIN vehicle v   ON v.vehicle_id   = b.vehicle_id
         WHERE b.status IN ('BOOKED', 'ONGOING', 'COMPLETED')
      ) WHERE balance > 0
      ORDER BY status, balance DESC;
    RETURN rc;
  END pending_dues;

  PROCEDURE print_branch_summary
  IS
    CURSOR c_branch IS
      SELECT branch_id, branch_name, city FROM branch ORDER BY branch_id;

    CURSOR c_fleet (cp_branch NUMBER) IS
      SELECT status, COUNT(*) AS cnt
        FROM vehicle WHERE branch_id = cp_branch
       GROUP BY status ORDER BY status;

    v_revenue NUMBER;
    v_line    VARCHAR2(200);
  BEGIN
    DBMS_OUTPUT.PUT_LINE('DRIVEEASE BRANCH SUMMARY  (' || TO_CHAR(SYSDATE, 'DD-Mon-YYYY HH24:MI') || ')');
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 70, '='));
    FOR br IN c_branch LOOP
      SELECT NVL(SUM(CASE WHEN p.payment_type = 'REFUND' THEN -p.amount ELSE p.amount END), 0)
        INTO v_revenue
        FROM payment p JOIN booking b ON b.booking_id = p.booking_id
       WHERE b.pickup_branch_id = br.branch_id AND p.txn_status = 'SUCCESS';

      v_line := NULL;
      FOR f IN c_fleet(br.branch_id) LOOP
        v_line := v_line || f.status || '=' || f.cnt || '  ';
      END LOOP;

      DBMS_OUTPUT.PUT_LINE(RPAD(br.branch_name || ' (' || br.city || ')', 34) ||
                           'Revenue: Rs.' || TO_CHAR(v_revenue, 'FM99,99,99,990.00'));
      DBMS_OUTPUT.PUT_LINE('    Fleet: ' || NVL(v_line, 'no vehicles'));
    END LOOP;
  END print_branch_summary;

END pkg_reports;
/

PROMPT Packages created.
