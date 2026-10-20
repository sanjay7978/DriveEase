-- =====================================================================
-- DriveEase (MySQL 8) - 02_functions.sql : stored FUNCTIONS
-- Derived values (age, rental days, amounts) are computed here instead
-- of being stored (Review I, Design Decision Q4).
-- =====================================================================
USE driveease;

DROP FUNCTION IF EXISTS fn_customer_age;
DROP FUNCTION IF EXISTS fn_rental_days;
DROP FUNCTION IF EXISTS fn_rental_amount;
DROP FUNCTION IF EXISTS fn_late_fee;
DROP FUNCTION IF EXISTS fn_total_paid;
DROP FUNCTION IF EXISTS fn_balance_due;
DROP FUNCTION IF EXISTS fn_is_vehicle_available;

DELIMITER $$

-- F1. Age of a customer in completed years on a given date (NULL = today)
CREATE FUNCTION fn_customer_age (p_customer_id INT, p_on_date DATETIME)
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE v_dob DATE DEFAULT NULL;
  SELECT dob INTO v_dob FROM customer WHERE customer_id = p_customer_id;
  IF v_dob IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20100, MESSAGE_TEXT = 'Customer does not exist';
  END IF;
  RETURN TIMESTAMPDIFF(YEAR, v_dob, COALESCE(p_on_date, NOW()));
END$$

-- F2. Rental days of a booking (BR-04: a started day counts, minimum one day)
CREATE FUNCTION fn_rental_days (p_booking_id INT)
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE v_start DATETIME DEFAULT NULL;
  DECLARE v_end   DATETIME;
  SELECT start_date, end_date INTO v_start, v_end FROM booking WHERE booking_id = p_booking_id;
  IF v_start IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20101, MESSAGE_TEXT = 'Booking does not exist';
  END IF;
  RETURN GREATEST(1, CEIL(TIMESTAMPDIFF(SECOND, v_start, v_end) / 86400));
END$$

-- F3. Rent = rental days x category daily rate (BR-04)
CREATE FUNCTION fn_rental_amount (p_booking_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
  DECLARE v_rate DECIMAL(8,2) DEFAULT NULL;
  SELECT c.daily_rate INTO v_rate
    FROM booking b
    JOIN vehicle v          ON v.vehicle_id  = b.vehicle_id
    JOIN vehicle_category c ON c.category_id = v.category_id
   WHERE b.booking_id = p_booking_id;
  IF v_rate IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20101, MESSAGE_TEXT = 'Booking does not exist';
  END IF;
  RETURN fn_rental_days(p_booking_id) * v_rate;
END$$

-- F4. Late fee = every started hour after end_date x late_fee_per_hr (BR-05)
--     p_return_date = "what if returned at ..."; NULL uses the recorded return.
CREATE FUNCTION fn_late_fee (p_booking_id INT, p_return_date DATETIME)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
  DECLARE v_end    DATETIME DEFAULT NULL;
  DECLARE v_actual DATETIME;
  DECLARE v_fee    DECIMAL(7,2);
  SELECT b.end_date, COALESCE(p_return_date, b.actual_return_date), c.late_fee_per_hr
    INTO v_end, v_actual, v_fee
    FROM booking b
    JOIN vehicle v          ON v.vehicle_id  = b.vehicle_id
    JOIN vehicle_category c ON c.category_id = v.category_id
   WHERE b.booking_id = p_booking_id;
  IF v_end IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20101, MESSAGE_TEXT = 'Booking does not exist';
  END IF;
  IF v_actual IS NULL OR v_actual <= v_end THEN
    RETURN 0;
  END IF;
  RETURN CEIL(TIMESTAMPDIFF(SECOND, v_end, v_actual) / 3600) * v_fee;   -- part hour = full hour
END$$

-- F5. Net amount received (successful payments minus refunds)
CREATE FUNCTION fn_total_paid (p_booking_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
  DECLARE v_total DECIMAL(10,2);
  SELECT COALESCE(SUM(CASE WHEN payment_type = 'REFUND' THEN -amount ELSE amount END), 0)
    INTO v_total
    FROM payment
   WHERE booking_id = p_booking_id AND txn_status = 'SUCCESS';
  RETURN v_total;
END$$

-- F6. Balance still owed by the customer
CREATE FUNCTION fn_balance_due (p_booking_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
  DECLARE v_status VARCHAR(12) DEFAULT NULL;
  SELECT status INTO v_status FROM booking WHERE booking_id = p_booking_id;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20101, MESSAGE_TEXT = 'Booking does not exist';
  END IF;
  IF v_status = 'CANCELLED' THEN
    RETURN 0;                                   -- nothing is owed on a cancelled booking
  END IF;
  RETURN GREATEST(0, fn_rental_amount(p_booking_id) + fn_late_fee(p_booking_id, NULL)
                     - fn_total_paid(p_booking_id));
END$$

-- F7. Is a vehicle free for a date range? 'Y' / 'N' (BR-02 + BR-03)
CREATE FUNCTION fn_is_vehicle_available (p_vehicle_id INT, p_start DATETIME, p_end DATETIME)
RETURNS CHAR(1)
READS SQL DATA
BEGIN
  DECLARE v_status  VARCHAR(12) DEFAULT NULL;
  DECLARE v_clashes INT;
  SELECT status INTO v_status FROM vehicle WHERE vehicle_id = p_vehicle_id;
  IF v_status IS NULL OR v_status IN ('MAINTENANCE', 'RETIRED') THEN
    RETURN 'N';
  END IF;
  SELECT COUNT(*) INTO v_clashes
    FROM booking
   WHERE vehicle_id = p_vehicle_id
     AND status IN ('BOOKED', 'ONGOING')
     AND start_date < p_end
     AND end_date   > p_start;
  RETURN IF(v_clashes = 0, 'Y', 'N');
END$$

DELIMITER ;

SELECT 'Functions created' AS status;
