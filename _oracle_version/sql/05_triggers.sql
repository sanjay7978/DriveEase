-- =====================================================================
-- DriveEase - 05_triggers.sql : TRIGGERS enforcing the business rules
-- inside the database (Non-functional requirement "Integrity").
-- =====================================================================
SET DEFINE OFF

-- T1. Customer data sanity on INSERT / UPDATE
CREATE OR REPLACE TRIGGER trg_customer_validate
BEFORE INSERT OR UPDATE OF dob, license_expiry, license_no ON customer
FOR EACH ROW
BEGIN
  :NEW.license_no := UPPER(TRIM(:NEW.license_no));
  IF :NEW.dob > SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20011, 'Date of birth cannot be in the future');
  END IF;
  IF MONTHS_BETWEEN(SYSDATE, :NEW.dob) / 12 < 18 THEN
    RAISE_APPLICATION_ERROR(-20012, 'A customer must be at least 18 to hold a driving licence');
  END IF;
  IF INSERTING AND :NEW.license_expiry <= TRUNC(SYSDATE) THEN
    RAISE_APPLICATION_ERROR(-20013, 'Driving licence has already expired');
  END IF;
END;
/

-- T2. Booking eligibility (BR-01, BR-03). A CHECK constraint cannot use
--     SYSDATE or other tables, so this is done in a trigger (Design Q5).
CREATE OR REPLACE TRIGGER trg_booking_eligibility
BEFORE INSERT OR UPDATE OF customer_id, vehicle_id, start_date, end_date ON booking
FOR EACH ROW
WHEN (NEW.status IN ('BOOKED', 'ONGOING'))
DECLARE
  v_dob     customer.dob%TYPE;
  v_expiry  customer.license_expiry%TYPE;
  v_vstatus vehicle.status%TYPE;
BEGIN
  SELECT dob, license_expiry INTO v_dob, v_expiry
    FROM customer WHERE customer_id = :NEW.customer_id;

  -- BR-01 (a): at least 21 years old on the pickup date
  IF MONTHS_BETWEEN(:NEW.start_date, v_dob) / 12 < 21 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Customer must be at least 21 years old on the pickup date (age ' ||
                            TRUNC(MONTHS_BETWEEN(:NEW.start_date, v_dob) / 12) || ')');
  END IF;

  -- BR-01 (b): licence valid for the whole rental
  IF v_expiry < :NEW.end_date THEN
    RAISE_APPLICATION_ERROR(-20002, 'Driving licence expires on ' || TO_CHAR(v_expiry, 'DD-Mon-YYYY') ||
                            ', before the booking ends');
  END IF;

  -- BR-03: vehicles under maintenance or retired cannot be booked
  IF INSERTING OR :NEW.vehicle_id <> :OLD.vehicle_id THEN
    SELECT status INTO v_vstatus FROM vehicle WHERE vehicle_id = :NEW.vehicle_id;
    IF v_vstatus IN ('MAINTENANCE', 'RETIRED') THEN
      RAISE_APPLICATION_ERROR(-20003, 'Vehicle ' || :NEW.vehicle_id || ' is ' || v_vstatus ||
                              ' and cannot be booked');
    END IF;
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20009, 'Customer or vehicle does not exist');
END;
/

-- T3. No double booking (BR-02). A COMPOUND trigger is used so that the
--     BOOKING table can be queried after the statement without raising
--     ORA-04091 (mutating table).
CREATE OR REPLACE TRIGGER trg_booking_no_overlap
FOR INSERT OR UPDATE OF vehicle_id, start_date, end_date, status ON booking
COMPOUND TRIGGER
  TYPE t_ids IS TABLE OF booking.booking_id%TYPE;
  g_ids t_ids := t_ids();

  AFTER EACH ROW IS
  BEGIN
    IF :NEW.status IN ('BOOKED', 'ONGOING') THEN
      g_ids.EXTEND;
      g_ids(g_ids.LAST) := :NEW.booking_id;
    END IF;
  END AFTER EACH ROW;

  AFTER STATEMENT IS
    v_clash booking.booking_id%TYPE;
  BEGIN
    FOR i IN 1 .. g_ids.COUNT LOOP
      BEGIN
        SELECT o.booking_id INTO v_clash
          FROM booking n
          JOIN booking o ON o.vehicle_id = n.vehicle_id
                        AND o.booking_id <> n.booking_id
                        AND o.status IN ('BOOKED', 'ONGOING')
                        AND o.start_date < n.end_date
                        AND o.end_date   > n.start_date
         WHERE n.booking_id = g_ids(i)
           AND ROWNUM = 1;
        RAISE_APPLICATION_ERROR(-20004, 'Vehicle is already booked for these dates (clashes with booking ' ||
                                v_clash || ')');
      EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;     -- no clash
      END;
    END LOOP;
    g_ids.DELETE;
  END AFTER STATEMENT;
END trg_booking_no_overlap;
/

-- T4. Booking status may only move forward:
--     BOOKED -> ONGOING | CANCELLED,  ONGOING -> COMPLETED
CREATE OR REPLACE TRIGGER trg_booking_status_flow
BEFORE UPDATE OF status ON booking
FOR EACH ROW
WHEN (NEW.status <> OLD.status)
BEGIN
  IF NOT ( (:OLD.status = 'BOOKED'  AND :NEW.status IN ('ONGOING', 'CANCELLED'))
        OR (:OLD.status = 'ONGOING' AND :NEW.status = 'COMPLETED') ) THEN
    RAISE_APPLICATION_ERROR(-20005, 'Invalid booking status change ' || :OLD.status ||
                            ' -> ' || :NEW.status);
  END IF;
END;
/

-- T5. Audit trail: every insert / status change / delete on BOOKING
CREATE OR REPLACE TRIGGER trg_booking_audit
AFTER INSERT OR UPDATE OR DELETE ON booking
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    INSERT INTO booking_audit (booking_id, action, old_status, new_status)
    VALUES (:NEW.booking_id, 'INSERT', NULL, :NEW.status);
  ELSIF UPDATING THEN
    IF NVL(:OLD.status, '-') <> NVL(:NEW.status, '-') THEN
      INSERT INTO booking_audit (booking_id, action, old_status, new_status)
      VALUES (:NEW.booking_id, 'UPDATE', :OLD.status, :NEW.status);
    END IF;
  ELSE
    INSERT INTO booking_audit (booking_id, action, old_status, new_status)
    VALUES (:OLD.booking_id, 'DELETE', :OLD.status, NULL);
  END IF;
END;
/

-- T6. A vehicle's odometer can never go backwards (supports BR-08)
CREATE OR REPLACE TRIGGER trg_vehicle_odometer
BEFORE UPDATE OF odometer ON vehicle
FOR EACH ROW
WHEN (NEW.odometer < OLD.odometer)
BEGIN
  RAISE_APPLICATION_ERROR(-20006, 'Odometer cannot decrease (' || :OLD.odometer ||
                          ' -> ' || :NEW.odometer || ')');
END;
/

-- T7. A rented or retired vehicle cannot be sent for maintenance
CREATE OR REPLACE TRIGGER trg_maint_before_insert
BEFORE INSERT ON maintenance
FOR EACH ROW
WHEN (NEW.maint_status IN ('SCHEDULED', 'IN_PROGRESS'))
DECLARE
  v_status vehicle.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM vehicle WHERE vehicle_id = :NEW.vehicle_id;
  IF v_status IN ('RENTED', 'RETIRED') THEN
    RAISE_APPLICATION_ERROR(-20007, 'Vehicle ' || :NEW.vehicle_id || ' is ' || v_status ||
                            ' and cannot be sent for maintenance');
  END IF;
END;
/

-- T8. Keep vehicle status in step with its maintenance jobs (FR-09, BR-03)
CREATE OR REPLACE TRIGGER trg_maint_vehicle_status
AFTER INSERT OR UPDATE OF maint_status ON maintenance
FOR EACH ROW
BEGIN
  IF :NEW.maint_status IN ('SCHEDULED', 'IN_PROGRESS') THEN
    UPDATE vehicle SET status = 'MAINTENANCE'
     WHERE vehicle_id = :NEW.vehicle_id AND status = 'AVAILABLE';
  ELSIF UPDATING AND :NEW.maint_status = 'DONE' THEN
    UPDATE vehicle SET status = 'AVAILABLE'
     WHERE vehicle_id = :NEW.vehicle_id AND status = 'MAINTENANCE';
  END IF;
END;
/

-- T9. Payments: nothing but a REFUND on a cancelled booking,
--     and a REFUND only on a cancelled or completed booking
CREATE OR REPLACE TRIGGER trg_payment_validate
BEFORE INSERT ON payment
FOR EACH ROW
DECLARE
  v_status booking.status%TYPE;
BEGIN
  SELECT status INTO v_status FROM booking WHERE booking_id = :NEW.booking_id;
  IF v_status = 'CANCELLED' AND :NEW.payment_type <> 'REFUND' THEN
    RAISE_APPLICATION_ERROR(-20008, 'Booking ' || :NEW.booking_id ||
                            ' is cancelled; only a REFUND can be recorded');
  END IF;
  IF :NEW.payment_type = 'REFUND' AND v_status NOT IN ('CANCELLED', 'COMPLETED') THEN
    RAISE_APPLICATION_ERROR(-20008, 'A REFUND can only be recorded on a cancelled or completed booking');
  END IF;
  :NEW.payment_date := NVL(:NEW.payment_date, SYSDATE);
END;
/

PROMPT Triggers created.
