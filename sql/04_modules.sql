-- =====================================================================
-- DriveEase (MySQL 8) - 04_modules.sql : VIEWS + "PACKAGE" MODULES
--
-- MySQL has no CREATE PACKAGE. The package idea (related procedures
-- grouped under one name, sharing private rules) is implemented as
-- MODULES: every routine of a module carries the module prefix.
--   rental_*  : booking life-cycle         (FR-03 .. FR-08, FR-12)
--   fleet_*   : maintenance                (FR-09)
--   report_*  : management reports         (FR-11)
-- Procedures that return rows send a result set (MySQL's equivalent
-- of an Oracle REF CURSOR). Explicit cursors are used in
-- rental_print_customer_history, fleet_auto_schedule_service and
-- report_branch_summary.
--
-- Transactions: multi-step procedures are atomic. If the caller has no
-- transaction open (e.g. a VS Code query tab with autocommit ON) the
-- procedure starts and commits its own; if the caller already has one
-- open (START TRANSACTION, the web app, the test suite) it works inside
-- it using a SAVEPOINT and leaves the COMMIT / ROLLBACK to the caller.
-- =====================================================================
USE driveease;

-- ---------------------------------------------------------------------
-- VIEWS used by the modules and the web app
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_vehicle_catalog AS
SELECT v.vehicle_id, v.reg_number, v.brand, v.model, v.mfg_year, v.fuel_type, v.transmission,
       v.odometer, v.status, c.category_id, c.category_name, c.daily_rate, c.late_fee_per_hr,
       c.seating_capacity, c.security_deposit, b.branch_id, b.branch_name, b.city
  FROM vehicle v
  JOIN vehicle_category c ON c.category_id = v.category_id
  JOIN branch b           ON b.branch_id   = v.branch_id;

CREATE OR REPLACE VIEW v_booking_summary AS
SELECT bk.booking_id, bk.status, bk.customer_id, cu.name AS customer, cu.phone,
       bk.vehicle_id, v.reg_number, CONCAT(v.brand, ' ', v.model) AS vehicle,
       bk.pickup_branch_id, pb.branch_name AS pickup_branch,
       bk.return_branch_id, rb.branch_name AS return_branch,
       bk.booking_date, bk.start_date, bk.end_date, bk.actual_return_date,
       bk.start_odometer, bk.end_odometer,
       fn_rental_days(bk.booking_id)         AS rental_days,
       fn_rental_amount(bk.booking_id)       AS rent,
       fn_late_fee(bk.booking_id, NULL)      AS late_fee,
       fn_total_paid(bk.booking_id)          AS paid,
       fn_balance_due(bk.booking_id)         AS balance
  FROM booking bk
  JOIN customer cu ON cu.customer_id = bk.customer_id
  JOIN vehicle v   ON v.vehicle_id   = bk.vehicle_id
  JOIN branch pb   ON pb.branch_id   = bk.pickup_branch_id
  JOIN branch rb   ON rb.branch_id   = bk.return_branch_id;

DROP PROCEDURE IF EXISTS rental_search_available;
DROP PROCEDURE IF EXISTS rental_add_payment;
DROP PROCEDURE IF EXISTS rental_create_booking;
DROP PROCEDURE IF EXISTS rental_record_pickup;
DROP PROCEDURE IF EXISTS rental_record_return;
DROP PROCEDURE IF EXISTS rental_cancel_booking;
DROP PROCEDURE IF EXISTS rental_customer_history;
DROP PROCEDURE IF EXISTS rental_print_customer_history;
DROP PROCEDURE IF EXISTS fleet_schedule_maintenance;
DROP PROCEDURE IF EXISTS fleet_update_maintenance;
DROP PROCEDURE IF EXISTS fleet_auto_schedule_service;
DROP PROCEDURE IF EXISTS report_branch_revenue;
DROP PROCEDURE IF EXISTS report_fleet_utilisation;
DROP PROCEDURE IF EXISTS report_top_customers;
DROP PROCEDURE IF EXISTS report_pending_dues;
DROP PROCEDURE IF EXISTS report_branch_summary;

DELIMITER $$

-- =====================================================================
-- MODULE rental_*
-- =====================================================================

-- FR-03 : vehicles free in a city / category for a date range (result set)
CREATE PROCEDURE rental_search_available (
  IN p_city VARCHAR(30), IN p_category_id INT, IN p_start DATETIME, IN p_end DATETIME
)
BEGIN
  IF p_end <= p_start THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20030, MESSAGE_TEXT = 'End date must be after start date';
  END IF;
  SELECT vehicle_id, reg_number, brand, model, fuel_type, transmission, category_name,
         daily_rate, seating_capacity, branch_id, branch_name, city,
         GREATEST(1, CEIL(TIMESTAMPDIFF(SECOND, p_start, p_end) / 86400)) * daily_rate AS estimated_rent
    FROM v_vehicle_catalog
   WHERE (p_city IS NULL OR p_city = '' OR city = p_city)
     AND (p_category_id IS NULL OR category_id = p_category_id)
     AND fn_is_vehicle_available(vehicle_id, p_start, p_end) = 'Y'
   ORDER BY daily_rate, vehicle_id;
END$$

-- FR-07 : record a payment (single INSERT, runs in the caller's transaction)
CREATE PROCEDURE rental_add_payment (
  IN p_booking_id INT, IN p_amount DECIMAL(9,2), IN p_method VARCHAR(12),
  IN p_payment_type VARCHAR(10), OUT p_payment_id INT
)
BEGIN
  DECLARE v_status VARCHAR(12) DEFAULT NULL;
  DECLARE v_msg    VARCHAR(128);

  SELECT status INTO v_status FROM booking WHERE booking_id = p_booking_id;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20101, MESSAGE_TEXT = 'Booking does not exist';
  END IF;
  IF UPPER(p_payment_type) = 'ADVANCE' AND v_status <> 'BOOKED' THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20070,
      MESSAGE_TEXT = 'An ADVANCE can only be paid while the booking is BOOKED';
  END IF;
  IF UPPER(p_payment_type) = 'REFUND' AND p_amount > fn_total_paid(p_booking_id) THEN
    SET v_msg = CONCAT('Refund cannot exceed the amount paid (', fn_total_paid(p_booking_id), ')');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20071, MESSAGE_TEXT = v_msg;
  END IF;

  INSERT INTO payment (booking_id, amount, method, payment_type)
  VALUES (p_booking_id, p_amount, UPPER(p_method), UPPER(p_payment_type));
  SET p_payment_id = LAST_INSERT_ID();
END$$

-- FR-04 : create a booking + advance payment in ONE transaction.
--         Age, licence, vehicle status and overlap are checked by triggers.
CREATE PROCEDURE rental_create_booking (
  IN  p_customer_id      INT,
  IN  p_vehicle_id       INT,
  IN  p_emp_id           INT,
  IN  p_return_branch_id INT,
  IN  p_start            DATETIME,
  IN  p_end              DATETIME,
  IN  p_advance          DECIMAL(9,2),
  IN  p_method           VARCHAR(12),
  OUT p_booking_id       INT
)
BEGIN
  DECLARE v_own    BOOLEAN DEFAULT FALSE;
  DECLARE v_branch INT DEFAULT NULL;
  DECLARE v_role   VARCHAR(15) DEFAULT NULL;
  DECLARE v_pay_id INT;
  DECLARE v_errno  INT;
  DECLARE v_text   VARCHAR(512);
  DECLARE v_msg    VARCHAR(128);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_text = MESSAGE_TEXT;
    IF v_own THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_create_booking; END IF;
    SET v_text = LEFT(v_text, 128);
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = v_errno, MESSAGE_TEXT = v_text;
  END;

  -- Does the caller already have a transaction open? A savepoint only survives
  -- inside one, so ROLLBACK TO fails (error 1305) when there is none.
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1305 SET v_own = TRUE;
    SAVEPOINT sp_create_booking;
    ROLLBACK TO SAVEPOINT sp_create_booking;
  END;
  IF v_own THEN START TRANSACTION; END IF;        -- run as our own transaction
  SAVEPOINT sp_create_booking;

  IF p_start < NOW() - INTERVAL 1 HOUR THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20031, MESSAGE_TEXT = 'Start date cannot be in the past';
  END IF;

  SELECT role INTO v_role FROM employee WHERE emp_id = p_emp_id;
  IF v_role IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20032, MESSAGE_TEXT = 'Employee does not exist';
  END IF;
  IF v_role NOT IN ('AGENT', 'MANAGER') THEN
    SET v_msg = CONCAT('Only an AGENT or MANAGER can create bookings (employee is ', v_role, ')');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20033, MESSAGE_TEXT = v_msg;
  END IF;

  SELECT branch_id INTO v_branch FROM vehicle WHERE vehicle_id = p_vehicle_id;
  IF v_branch IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20034, MESSAGE_TEXT = 'Vehicle does not exist';
  END IF;

  -- the vehicle is picked up from its current home branch
  INSERT INTO booking (customer_id, vehicle_id, emp_id, pickup_branch_id, return_branch_id,
                       start_date, end_date, status)
  VALUES (p_customer_id, p_vehicle_id, p_emp_id, v_branch, COALESCE(p_return_branch_id, v_branch),
          p_start, p_end, 'BOOKED');
  SET p_booking_id = LAST_INSERT_ID();

  IF COALESCE(p_advance, 0) > 0 THEN
    CALL rental_add_payment(p_booking_id, p_advance, COALESCE(p_method, 'CASH'), 'ADVANCE', v_pay_id);
  END IF;

  IF v_own THEN COMMIT; END IF;
END$$

-- FR-05 : pickup - booking ONGOING, vehicle RENTED
CREATE PROCEDURE rental_record_pickup (IN p_booking_id INT, IN p_start_odometer INT)
BEGIN
  DECLARE v_own      BOOLEAN DEFAULT FALSE;
  DECLARE v_bstatus  VARCHAR(12) DEFAULT NULL;
  DECLARE v_start    DATETIME;
  DECLARE v_vehicle  INT;
  DECLARE v_odo      INT;
  DECLARE v_vstatus  VARCHAR(12);
  DECLARE v_errno    INT;
  DECLARE v_text     VARCHAR(512);
  DECLARE v_msg      VARCHAR(128);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_text = MESSAGE_TEXT;
    IF v_own THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_record_pickup; END IF;
    SET v_text = LEFT(v_text, 128);
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = v_errno, MESSAGE_TEXT = v_text;
  END;

  -- Does the caller already have a transaction open? A savepoint only survives
  -- inside one, so ROLLBACK TO fails (error 1305) when there is none.
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1305 SET v_own = TRUE;
    SAVEPOINT sp_record_pickup;
    ROLLBACK TO SAVEPOINT sp_record_pickup;
  END;
  IF v_own THEN START TRANSACTION; END IF;        -- run as our own transaction
  SAVEPOINT sp_record_pickup;

  SELECT status, start_date, vehicle_id INTO v_bstatus, v_start, v_vehicle
    FROM booking WHERE booking_id = p_booking_id FOR UPDATE;
  IF v_bstatus IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20101, MESSAGE_TEXT = 'Booking does not exist';
  END IF;
  IF v_bstatus <> 'BOOKED' THEN
    SET v_msg = CONCAT('Only a BOOKED booking can be picked up (status is ', v_bstatus, ')');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20040, MESSAGE_TEXT = v_msg;
  END IF;
  IF NOW() < v_start - INTERVAL 1 DAY THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20041, MESSAGE_TEXT = 'Pickup is allowed at most 1 day before the start date';
  END IF;

  SELECT odometer, status INTO v_odo, v_vstatus FROM vehicle WHERE vehicle_id = v_vehicle FOR UPDATE;
  IF v_vstatus <> 'AVAILABLE' THEN
    SET v_msg = CONCAT('Vehicle is ', v_vstatus, ' and cannot be handed over');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20042, MESSAGE_TEXT = v_msg;
  END IF;
  IF p_start_odometer < v_odo THEN
    SET v_msg = CONCAT('Start odometer (', p_start_odometer, ') is lower than the vehicle odometer (', v_odo, ')');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20043, MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE booking SET status = 'ONGOING', start_odometer = p_start_odometer WHERE booking_id = p_booking_id;
  UPDATE vehicle SET status = 'RENTED', odometer = p_start_odometer WHERE vehicle_id = v_vehicle;

  IF v_own THEN COMMIT; END IF;
END$$

-- FR-06 : return - rent + late fee (BR-04, BR-05), one-way transfer (BR-07),
--         optional settlement of the balance at the counter
CREATE PROCEDURE rental_record_return (
  IN p_booking_id INT, IN p_end_odometer INT, IN p_return_date DATETIME,
  IN p_method VARCHAR(12), OUT p_amount_due DECIMAL(10,2)
)
BEGIN
  DECLARE v_own      BOOLEAN DEFAULT FALSE;
  DECLARE v_bstatus  VARCHAR(12) DEFAULT NULL;
  DECLARE v_vehicle  INT;
  DECLARE v_start_odo INT;
  DECLARE v_ret_branch INT;
  DECLARE v_rent     DECIMAL(10,2);
  DECLARE v_late     DECIMAL(10,2);
  DECLARE v_paid     DECIMAL(10,2);
  DECLARE v_rent_due DECIMAL(10,2);
  DECLARE v_pay_id   INT;
  DECLARE v_errno    INT;
  DECLARE v_text     VARCHAR(512);
  DECLARE v_msg      VARCHAR(128);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_text = MESSAGE_TEXT;
    IF v_own THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_record_return; END IF;
    SET v_text = LEFT(v_text, 128);
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = v_errno, MESSAGE_TEXT = v_text;
  END;

  -- Does the caller already have a transaction open? A savepoint only survives
  -- inside one, so ROLLBACK TO fails (error 1305) when there is none.
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1305 SET v_own = TRUE;
    SAVEPOINT sp_record_return;
    ROLLBACK TO SAVEPOINT sp_record_return;
  END;
  IF v_own THEN START TRANSACTION; END IF;        -- run as our own transaction
  SAVEPOINT sp_record_return;

  SELECT status, vehicle_id, start_odometer, return_branch_id
    INTO v_bstatus, v_vehicle, v_start_odo, v_ret_branch
    FROM booking WHERE booking_id = p_booking_id FOR UPDATE;
  IF v_bstatus IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20101, MESSAGE_TEXT = 'Booking does not exist';
  END IF;
  IF v_bstatus <> 'ONGOING' THEN
    SET v_msg = CONCAT('Only an ONGOING booking can be returned (status is ', v_bstatus, ')');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20050, MESSAGE_TEXT = v_msg;
  END IF;
  IF p_end_odometer < v_start_odo THEN                                   -- BR-08
    SET v_msg = CONCAT('End odometer (', p_end_odometer, ') cannot be lower than start odometer (', v_start_odo, ')');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20051, MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE booking
     SET status = 'COMPLETED', end_odometer = p_end_odometer,
         actual_return_date = COALESCE(p_return_date, NOW())
   WHERE booking_id = p_booking_id;

  -- vehicle is free again and now belongs to the return branch (BR-07)
  UPDATE vehicle
     SET status = 'AVAILABLE', odometer = p_end_odometer, branch_id = v_ret_branch
   WHERE vehicle_id = v_vehicle;

  SET v_rent = fn_rental_amount(p_booking_id);
  SET v_late = fn_late_fee(p_booking_id, NULL);
  SET v_paid = fn_total_paid(p_booking_id);
  SET p_amount_due = GREATEST(0, v_rent + v_late - v_paid);

  IF p_method IS NOT NULL AND p_method <> '' AND p_amount_due > 0 THEN
    SET v_rent_due = GREATEST(0, v_rent - v_paid);
    IF v_rent_due > 0 THEN
      CALL rental_add_payment(p_booking_id, v_rent_due, p_method, 'FINAL', v_pay_id);
    END IF;
    IF p_amount_due - v_rent_due > 0 THEN
      CALL rental_add_payment(p_booking_id, p_amount_due - v_rent_due, p_method, 'LATE_FEE', v_pay_id);
    END IF;
    SET p_amount_due = fn_balance_due(p_booking_id);
  END IF;

  IF v_own THEN COMMIT; END IF;
END$$

-- FR-08 : cancel - BR-06: >= 24 h before pickup full refund, otherwise 50 %
CREATE PROCEDURE rental_cancel_booking (IN p_booking_id INT, OUT p_refund DECIMAL(10,2))
BEGIN
  DECLARE v_own     BOOLEAN DEFAULT FALSE;
  DECLARE v_bstatus VARCHAR(12) DEFAULT NULL;
  DECLARE v_start   DATETIME;
  DECLARE v_advance DECIMAL(10,2);
  DECLARE v_method  VARCHAR(12);
  DECLARE v_pay_id  INT;
  DECLARE v_errno   INT;
  DECLARE v_text    VARCHAR(512);
  DECLARE v_msg     VARCHAR(128);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_text = MESSAGE_TEXT;
    IF v_own THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_cancel_booking; END IF;
    SET v_text = LEFT(v_text, 128);
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = v_errno, MESSAGE_TEXT = v_text;
  END;

  -- Does the caller already have a transaction open? A savepoint only survives
  -- inside one, so ROLLBACK TO fails (error 1305) when there is none.
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1305 SET v_own = TRUE;
    SAVEPOINT sp_cancel_booking;
    ROLLBACK TO SAVEPOINT sp_cancel_booking;
  END;
  IF v_own THEN START TRANSACTION; END IF;        -- run as our own transaction
  SAVEPOINT sp_cancel_booking;

  SELECT status, start_date INTO v_bstatus, v_start FROM booking WHERE booking_id = p_booking_id FOR UPDATE;
  IF v_bstatus IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20101, MESSAGE_TEXT = 'Booking does not exist';
  END IF;
  IF v_bstatus <> 'BOOKED' THEN
    SET v_msg = CONCAT('Only a BOOKED booking can be cancelled (status is ', v_bstatus, ')');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20060, MESSAGE_TEXT = v_msg;
  END IF;

  SELECT COALESCE(SUM(amount), 0), MAX(method) INTO v_advance, v_method
    FROM payment
   WHERE booking_id = p_booking_id AND payment_type = 'ADVANCE' AND txn_status = 'SUCCESS';

  IF TIMESTAMPDIFF(SECOND, NOW(), v_start) >= 24 * 3600 THEN
    SET p_refund = v_advance;
  ELSE
    SET p_refund = ROUND(v_advance * 0.5, 2);
  END IF;

  UPDATE booking SET status = 'CANCELLED' WHERE booking_id = p_booking_id;
  IF p_refund > 0 THEN
    CALL rental_add_payment(p_booking_id, p_refund, v_method, 'REFUND', v_pay_id);
  END IF;

  IF v_own THEN COMMIT; END IF;
END$$

-- FR-12 : customer history (result set)
CREATE PROCEDURE rental_customer_history (IN p_customer_id INT)
BEGIN
  SELECT booking_id, status, start_date, end_date, actual_return_date, reg_number, vehicle,
         pickup_branch, return_branch, rent, late_fee, paid, balance
    FROM v_booking_summary
   WHERE customer_id = p_customer_id
   ORDER BY start_date DESC;
END$$

-- FR-12 : the same history built with NESTED EXPLICIT CURSORS
--         (outer cursor = bookings, inner cursor = payments of each booking)
CREATE PROCEDURE rental_print_customer_history (IN p_customer_id INT)
BEGIN
  DECLARE v_name    VARCHAR(50) DEFAULT NULL;
  DECLARE v_done    INT DEFAULT 0;
  DECLARE v_count   INT DEFAULT 0;
  DECLARE v_bid     INT;
  DECLARE v_status  VARCHAR(12);
  DECLARE v_start   DATETIME;
  DECLARE v_end     DATETIME;
  DECLARE v_vehicle VARCHAR(70);

  DECLARE c_bookings CURSOR FOR
    SELECT bk.booking_id, bk.status, bk.start_date, bk.end_date,
           CONCAT(v.brand, ' ', v.model, ' (', v.reg_number, ')')
      FROM booking bk JOIN vehicle v ON v.vehicle_id = bk.vehicle_id
     WHERE bk.customer_id = p_customer_id
     ORDER BY bk.start_date;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  SELECT name INTO v_name FROM customer WHERE customer_id = p_customer_id;
  SET v_done = 0;
  IF v_name IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20100, MESSAGE_TEXT = 'Customer does not exist';
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_history;
  CREATE TEMPORARY TABLE tmp_history (line_no INT AUTO_INCREMENT PRIMARY KEY, line VARCHAR(200));
  INSERT INTO tmp_history (line) VALUES
    (CONCAT('Rental history of ', v_name, ' (customer ', p_customer_id,
            ', age ', fn_customer_age(p_customer_id, NULL), ')'));

  OPEN c_bookings;
  booking_loop: LOOP
    FETCH c_bookings INTO v_bid, v_status, v_start, v_end, v_vehicle;
    IF v_done = 1 THEN LEAVE booking_loop; END IF;
    SET v_count = v_count + 1;
    INSERT INTO tmp_history (line) VALUES
      (CONCAT('Booking ', v_bid, '  ', RPAD(v_status, 10, ' '), DATE_FORMAT(v_start, '%d-%b-%y'),
              ' -> ', DATE_FORMAT(v_end, '%d-%b-%y'), '  ', v_vehicle)),
      (CONCAT('    rent ', fn_rental_amount(v_bid), ', late fee ', fn_late_fee(v_bid, NULL),
              ', paid ', fn_total_paid(v_bid), ', balance ', fn_balance_due(v_bid)));

    -- inner cursor: payments of this booking
    BEGIN
      DECLARE v_pdone  INT DEFAULT 0;
      DECLARE v_pid    INT;
      DECLARE v_ptype  VARCHAR(10);
      DECLARE v_method VARCHAR(12);
      DECLARE v_amount DECIMAL(9,2);
      DECLARE c_payments CURSOR FOR
        SELECT payment_id, payment_type, method, amount
          FROM payment WHERE booking_id = v_bid ORDER BY payment_date, payment_id;
      DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_pdone = 1;

      OPEN c_payments;
      payment_loop: LOOP
        FETCH c_payments INTO v_pid, v_ptype, v_method, v_amount;
        IF v_pdone = 1 THEN LEAVE payment_loop; END IF;
        INSERT INTO tmp_history (line) VALUES
          (CONCAT('      - payment ', v_pid, ' ', RPAD(v_ptype, 9, ' '), RPAD(v_method, 11, ' '), v_amount));
      END LOOP;
      CLOSE c_payments;
    END;
  END LOOP;
  CLOSE c_bookings;

  INSERT INTO tmp_history (line) VALUES (CONCAT(v_count, ' booking(s) found.'));
  SELECT line AS customer_history FROM tmp_history ORDER BY line_no;
  DROP TEMPORARY TABLE tmp_history;
END$$

-- =====================================================================
-- MODULE fleet_*   (FR-09)
-- =====================================================================
CREATE PROCEDURE fleet_schedule_maintenance (
  IN p_vehicle_id INT, IN p_service_type VARCHAR(20), IN p_description VARCHAR(200),
  IN p_service_date DATETIME, OUT p_maint_id INT
)
BEGIN
  DECLARE v_open INT;
  SELECT COUNT(*) INTO v_open
    FROM maintenance
   WHERE vehicle_id = p_vehicle_id AND maint_status IN ('SCHEDULED', 'IN_PROGRESS');
  IF v_open > 0 THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20080, MESSAGE_TEXT = 'Vehicle already has an open maintenance job';
  END IF;

  -- trigger trg_maint_before_insert blocks rented / retired vehicles and
  -- trigger trg_maint_after_insert moves the vehicle to MAINTENANCE
  INSERT INTO maintenance (vehicle_id, service_date, service_type, description, maint_status)
  VALUES (p_vehicle_id, COALESCE(p_service_date, NOW()), UPPER(p_service_type),
          NULLIF(p_description, ''), 'SCHEDULED');
  SET p_maint_id = LAST_INSERT_ID();
END$$

CREATE PROCEDURE fleet_update_maintenance (IN p_maint_id INT, IN p_status VARCHAR(12), IN p_cost DECIMAL(9,2))
BEGIN
  DECLARE v_old VARCHAR(12) DEFAULT NULL;
  SELECT maint_status INTO v_old FROM maintenance WHERE maint_id = p_maint_id FOR UPDATE;
  IF v_old IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20082, MESSAGE_TEXT = 'Maintenance job does not exist';
  END IF;
  IF v_old = 'DONE' THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20081, MESSAGE_TEXT = 'Maintenance job is already closed';
  END IF;
  UPDATE maintenance
     SET maint_status = UPPER(p_status), cost = COALESCE(p_cost, cost)
   WHERE maint_id = p_maint_id;
END$$

-- Explicit cursor (DECLARE / OPEN / FETCH / NOT FOUND handler / CLOSE):
-- schedule a GENERAL service for every available vehicle not serviced
-- in the last 180 days (skipping vehicles booked in the next 3 days).
CREATE PROCEDURE fleet_auto_schedule_service (OUT p_jobs_created INT)
BEGIN
  DECLARE v_own     BOOLEAN DEFAULT FALSE;
  DECLARE v_done    INT DEFAULT 0;
  DECLARE v_checked INT DEFAULT 0;
  DECLARE v_vid     INT;
  DECLARE v_reg     VARCHAR(12);
  DECLARE v_last    DATETIME;
  DECLARE v_errno   INT;
  DECLARE v_text    VARCHAR(512);

  DECLARE c_due CURSOR FOR
    SELECT v.vehicle_id, v.reg_number,
           (SELECT MAX(m.service_date) FROM maintenance m
             WHERE m.vehicle_id = v.vehicle_id AND m.service_type = 'GENERAL'
               AND m.maint_status = 'DONE') AS last_service
      FROM vehicle v
     WHERE v.status = 'AVAILABLE'
       AND NOT EXISTS (SELECT 1 FROM maintenance m
                        WHERE m.vehicle_id = v.vehicle_id AND m.maint_status IN ('SCHEDULED', 'IN_PROGRESS'))
       AND NOT EXISTS (SELECT 1 FROM booking b
                        WHERE b.vehicle_id = v.vehicle_id AND b.status = 'BOOKED'
                          AND b.start_date < NOW() + INTERVAL 3 DAY)
     ORDER BY v.vehicle_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_text = MESSAGE_TEXT;
    IF v_own THEN ROLLBACK; ELSE ROLLBACK TO SAVEPOINT sp_auto_service; END IF;
    SET v_text = LEFT(v_text, 128);
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = v_errno, MESSAGE_TEXT = v_text;
  END;

  -- Does the caller already have a transaction open? A savepoint only survives
  -- inside one, so ROLLBACK TO fails (error 1305) when there is none.
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1305 SET v_own = TRUE;
    SAVEPOINT sp_auto_service;
    ROLLBACK TO SAVEPOINT sp_auto_service;
  END;
  IF v_own THEN START TRANSACTION; END IF;        -- run as our own transaction
  SAVEPOINT sp_auto_service;
  SET p_jobs_created = 0;

  OPEN c_due;
  due_loop: LOOP
    FETCH c_due INTO v_vid, v_reg, v_last;
    IF v_done = 1 THEN LEAVE due_loop; END IF;
    SET v_checked = v_checked + 1;
    IF v_last IS NULL OR v_last < NOW() - INTERVAL 180 DAY THEN
      INSERT INTO maintenance (vehicle_id, service_date, service_type, description, maint_status)
      VALUES (v_vid, CURDATE() + INTERVAL 1 DAY, 'GENERAL',
              CONCAT('Auto: periodic service (last ', COALESCE(DATE_FORMAT(v_last, '%d-%b-%Y'), 'never'), ')'),
              'SCHEDULED');
      SET p_jobs_created = p_jobs_created + 1;
    END IF;
  END LOOP;
  CLOSE c_due;

  IF v_own THEN COMMIT; END IF;
END$$

-- =====================================================================
-- MODULE report_*   (FR-11) - each returns a result set
-- =====================================================================
CREATE PROCEDURE report_branch_revenue (IN p_months INT)
BEGIN
  SELECT br.branch_name,
         DATE_FORMAT(p.payment_date, '%Y-%m') AS month,
         SUM(CASE WHEN p.payment_type = 'REFUND' THEN -p.amount ELSE p.amount END) AS revenue,
         COUNT(DISTINCT p.booking_id) AS bookings
    FROM payment p
    JOIN booking b ON b.booking_id = p.booking_id
    JOIN branch br ON br.branch_id = b.pickup_branch_id
   WHERE p.txn_status = 'SUCCESS'
     AND p.payment_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01') - INTERVAL (COALESCE(p_months, 6) - 1) MONTH
   GROUP BY br.branch_name, DATE_FORMAT(p.payment_date, '%Y-%m')
   ORDER BY month DESC, revenue DESC;
END$$

CREATE PROCEDURE report_fleet_utilisation (IN p_days INT)
BEGIN
  DECLARE v_days INT DEFAULT COALESCE(p_days, 30);
  SELECT x.vehicle_id, x.reg_number, x.vehicle, x.category_name, x.branch_name, x.status,
         ROUND(x.secs / 86400, 1) AS days_rented,
         ROUND(100 * x.secs / (v_days * 86400), 1) AS utilisation_pct
    FROM (
      SELECT v.vehicle_id, v.reg_number, CONCAT(v.brand, ' ', v.model) AS vehicle,
             c.category_name, br.branch_name, v.status,
             COALESCE(SUM(GREATEST(0, TIMESTAMPDIFF(SECOND,
                 GREATEST(b.start_date, NOW() - INTERVAL v_days DAY),
                 LEAST(COALESCE(b.actual_return_date, NOW()), NOW())))), 0) AS secs
        FROM vehicle v
        JOIN vehicle_category c ON c.category_id = v.category_id
        JOIN branch br          ON br.branch_id  = v.branch_id
        LEFT JOIN booking b     ON b.vehicle_id  = v.vehicle_id AND b.status IN ('ONGOING', 'COMPLETED')
       WHERE v.status <> 'RETIRED'
       GROUP BY v.vehicle_id, v.reg_number, v.brand, v.model, c.category_name, br.branch_name, v.status
    ) x
   ORDER BY utilisation_pct DESC, x.vehicle_id;
END$$

CREATE PROCEDURE report_top_customers (IN p_limit INT)
BEGIN
  SELECT cu.customer_id, cu.name, cu.phone,
         COUNT(*) AS rentals,
         SUM(fn_total_paid(b.booking_id)) AS total_spent
    FROM customer cu
    JOIN booking b ON b.customer_id = cu.customer_id
   WHERE b.status IN ('ONGOING', 'COMPLETED')
   GROUP BY cu.customer_id, cu.name, cu.phone
   ORDER BY rentals DESC, total_spent DESC
   LIMIT p_limit;
END$$

CREATE PROCEDURE report_pending_dues ()
BEGIN
  SELECT booking_id, customer, phone, status, reg_number, end_date,
         rent + late_fee AS total_charge, paid, balance
    FROM v_booking_summary
   WHERE status IN ('BOOKED', 'ONGOING', 'COMPLETED') AND balance > 0
   ORDER BY FIELD(status, 'COMPLETED', 'ONGOING', 'BOOKED'), balance DESC;
END$$

-- Branch summary built with NESTED EXPLICIT CURSORS
CREATE PROCEDURE report_branch_summary ()
BEGIN
  DECLARE v_done   INT DEFAULT 0;
  DECLARE v_bid    INT;
  DECLARE v_bname  VARCHAR(50);
  DECLARE v_city   VARCHAR(30);
  DECLARE v_rev    DECIMAL(12,2);
  DECLARE v_fleet  VARCHAR(200);
  DECLARE c_branch CURSOR FOR SELECT branch_id, branch_name, city FROM branch ORDER BY branch_id;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

  DROP TEMPORARY TABLE IF EXISTS tmp_branch_summary;
  CREATE TEMPORARY TABLE tmp_branch_summary (
    branch VARCHAR(90), revenue DECIMAL(12,2), fleet VARCHAR(200));

  OPEN c_branch;
  branch_loop: LOOP
    FETCH c_branch INTO v_bid, v_bname, v_city;
    IF v_done = 1 THEN LEAVE branch_loop; END IF;

    SELECT COALESCE(SUM(CASE WHEN p.payment_type = 'REFUND' THEN -p.amount ELSE p.amount END), 0)
      INTO v_rev
      FROM payment p JOIN booking b ON b.booking_id = p.booking_id
     WHERE b.pickup_branch_id = v_bid AND p.txn_status = 'SUCCESS';

    -- inner cursor: vehicle count per status at this branch
    BEGIN
      DECLARE v_fdone  INT DEFAULT 0;
      DECLARE v_status VARCHAR(12);
      DECLARE v_cnt    INT;
      DECLARE c_fleet CURSOR FOR
        SELECT status, COUNT(*) FROM vehicle WHERE branch_id = v_bid GROUP BY status ORDER BY status;
      DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fdone = 1;
      SET v_fleet = '';
      OPEN c_fleet;
      fleet_loop: LOOP
        FETCH c_fleet INTO v_status, v_cnt;
        IF v_fdone = 1 THEN LEAVE fleet_loop; END IF;
        SET v_fleet = CONCAT(v_fleet, v_status, '=', v_cnt, '  ');
      END LOOP;
      CLOSE c_fleet;
    END;

    INSERT INTO tmp_branch_summary VALUES
      (CONCAT(v_bname, ' (', v_city, ')'), v_rev, NULLIF(TRIM(v_fleet), ''));
  END LOOP;
  CLOSE c_branch;

  SELECT * FROM tmp_branch_summary;
  DROP TEMPORARY TABLE tmp_branch_summary;
END$$

DELIMITER ;

SELECT 'Views and modules created' AS status;
