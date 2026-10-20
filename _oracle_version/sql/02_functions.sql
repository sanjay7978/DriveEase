-- =====================================================================
-- DriveEase - 02_functions.sql : stand-alone PL/SQL FUNCTIONS
-- Derived values (age, rental days, amounts) are computed here instead
-- of being stored (Design Decision Q4).
-- =====================================================================
SET DEFINE OFF

-- F1. Age of a customer in completed years on a given date
CREATE OR REPLACE FUNCTION fn_customer_age (
  p_customer_id IN customer.customer_id%TYPE,
  p_on_date     IN DATE DEFAULT SYSDATE
) RETURN NUMBER
IS
  v_dob customer.dob%TYPE;
BEGIN
  SELECT dob INTO v_dob FROM customer WHERE customer_id = p_customer_id;
  RETURN TRUNC(MONTHS_BETWEEN(p_on_date, v_dob) / 12);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20100, 'Customer ' || p_customer_id || ' does not exist');
END fn_customer_age;
/

-- F2. Number of rental days of a booking (BR-04: minimum one day)
CREATE OR REPLACE FUNCTION fn_rental_days (
  p_booking_id IN booking.booking_id%TYPE
) RETURN NUMBER
IS
  v_start booking.start_date%TYPE;
  v_end   booking.end_date%TYPE;
BEGIN
  SELECT start_date, end_date INTO v_start, v_end
    FROM booking WHERE booking_id = p_booking_id;
  RETURN GREATEST(1, CEIL(ROUND(v_end - v_start, 6)));
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20101, 'Booking ' || p_booking_id || ' does not exist');
END fn_rental_days;
/

-- F3. Rent of a booking = rental days x category daily rate (BR-04)
CREATE OR REPLACE FUNCTION fn_rental_amount (
  p_booking_id IN booking.booking_id%TYPE
) RETURN NUMBER
IS
  v_rate vehicle_category.daily_rate%TYPE;
BEGIN
  SELECT c.daily_rate INTO v_rate
    FROM booking b
    JOIN vehicle v          ON v.vehicle_id  = b.vehicle_id
    JOIN vehicle_category c ON c.category_id = v.category_id
   WHERE b.booking_id = p_booking_id;
  RETURN fn_rental_days(p_booking_id) * v_rate;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20101, 'Booking ' || p_booking_id || ' does not exist');
END fn_rental_amount;
/

-- F4. Late fee = every started hour after end_date x late_fee_per_hr (BR-05)
--     p_return_date lets the caller ask "what if returned at ..." ;
--     NULL means use the recorded actual_return_date.
CREATE OR REPLACE FUNCTION fn_late_fee (
  p_booking_id  IN booking.booking_id%TYPE,
  p_return_date IN DATE DEFAULT NULL
) RETURN NUMBER
IS
  v_end    booking.end_date%TYPE;
  v_actual booking.actual_return_date%TYPE;
  v_fee    vehicle_category.late_fee_per_hr%TYPE;
  v_hours  NUMBER;
BEGIN
  SELECT b.end_date, NVL(p_return_date, b.actual_return_date), c.late_fee_per_hr
    INTO v_end, v_actual, v_fee
    FROM booking b
    JOIN vehicle v          ON v.vehicle_id  = b.vehicle_id
    JOIN vehicle_category c ON c.category_id = v.category_id
   WHERE b.booking_id = p_booking_id;

  IF v_actual IS NULL OR v_actual <= v_end THEN
    RETURN 0;
  END IF;
  v_hours := CEIL(ROUND((v_actual - v_end) * 24, 4));   -- partial hour counts as a full hour
  RETURN v_hours * v_fee;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20101, 'Booking ' || p_booking_id || ' does not exist');
END fn_late_fee;
/

-- F5. Net amount received for a booking (successful payments minus refunds)
CREATE OR REPLACE FUNCTION fn_total_paid (
  p_booking_id IN booking.booking_id%TYPE
) RETURN NUMBER
IS
  v_total NUMBER;
BEGIN
  SELECT NVL(SUM(CASE WHEN payment_type = 'REFUND' THEN -amount ELSE amount END), 0)
    INTO v_total
    FROM payment
   WHERE booking_id = p_booking_id
     AND txn_status = 'SUCCESS';
  RETURN v_total;
END fn_total_paid;
/

-- F6. Balance still owed by the customer for a booking
CREATE OR REPLACE FUNCTION fn_balance_due (
  p_booking_id IN booking.booking_id%TYPE
) RETURN NUMBER
IS
  v_status booking.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM booking WHERE booking_id = p_booking_id;
  IF v_status = 'CANCELLED' THEN
    RETURN 0;                                   -- nothing is owed on a cancelled booking
  END IF;
  RETURN GREATEST(0, fn_rental_amount(p_booking_id)
                     + fn_late_fee(p_booking_id)
                     - fn_total_paid(p_booking_id));
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20101, 'Booking ' || p_booking_id || ' does not exist');
END fn_balance_due;
/

-- F7. Is a vehicle free for a date range? Returns 'Y' / 'N' so it can be used in SQL.
--     Checks status (BR-03) and overlapping BOOKED/ONGOING bookings (BR-02).
CREATE OR REPLACE FUNCTION fn_is_vehicle_available (
  p_vehicle_id IN vehicle.vehicle_id%TYPE,
  p_start      IN DATE,
  p_end        IN DATE,
  p_ignore_booking IN booking.booking_id%TYPE DEFAULT NULL
) RETURN VARCHAR2
IS
  v_status  vehicle.status%TYPE;
  v_clashes NUMBER;
BEGIN
  SELECT status INTO v_status FROM vehicle WHERE vehicle_id = p_vehicle_id;
  IF v_status IN ('MAINTENANCE', 'RETIRED') THEN
    RETURN 'N';
  END IF;

  SELECT COUNT(*) INTO v_clashes
    FROM booking
   WHERE vehicle_id = p_vehicle_id
     AND status IN ('BOOKED', 'ONGOING')
     AND booking_id <> NVL(p_ignore_booking, -1)
     AND start_date < p_end
     AND end_date   > p_start;

  RETURN CASE WHEN v_clashes = 0 THEN 'Y' ELSE 'N' END;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 'N';
END fn_is_vehicle_available;
/

PROMPT Functions created.
