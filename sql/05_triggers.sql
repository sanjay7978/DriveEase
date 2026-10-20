-- =====================================================================
-- DriveEase (MySQL 8) - 05_triggers.sql : TRIGGERS enforcing the
-- business rules inside the database (NFR "Integrity").
-- MySQL needs one trigger per timing+event, so rules on BOOKING are
-- split into BEFORE INSERT / BEFORE UPDATE / AFTER triggers.
-- =====================================================================
USE driveease;

DROP TRIGGER IF EXISTS trg_customer_before_insert;
DROP TRIGGER IF EXISTS trg_customer_before_update;
DROP TRIGGER IF EXISTS trg_booking_before_insert;
DROP TRIGGER IF EXISTS trg_booking_before_update;
DROP TRIGGER IF EXISTS trg_booking_after_insert;
DROP TRIGGER IF EXISTS trg_booking_after_update;
DROP TRIGGER IF EXISTS trg_booking_after_delete;
DROP TRIGGER IF EXISTS trg_vehicle_before_update;
DROP TRIGGER IF EXISTS trg_maint_before_insert;
DROP TRIGGER IF EXISTS trg_maint_after_insert;
DROP TRIGGER IF EXISTS trg_maint_after_update;
DROP TRIGGER IF EXISTS trg_payment_before_insert;

DELIMITER $$

-- T1. Customer data sanity on INSERT
CREATE TRIGGER trg_customer_before_insert
BEFORE INSERT ON customer
FOR EACH ROW
BEGIN
  SET NEW.license_no = UPPER(TRIM(NEW.license_no));
  IF NEW.dob > CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20011, MESSAGE_TEXT = 'Date of birth cannot be in the future';
  END IF;
  IF TIMESTAMPDIFF(YEAR, NEW.dob, CURDATE()) < 18 THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20012, MESSAGE_TEXT = 'A customer must be at least 18 to hold a driving licence';
  END IF;
  IF NEW.license_expiry <= CURDATE() THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20013, MESSAGE_TEXT = 'Driving licence has already expired';
  END IF;
END$$

-- T2. Customer data sanity on UPDATE
CREATE TRIGGER trg_customer_before_update
BEFORE UPDATE ON customer
FOR EACH ROW
BEGIN
  SET NEW.license_no = UPPER(TRIM(NEW.license_no));
  IF NEW.dob > CURDATE() OR TIMESTAMPDIFF(YEAR, NEW.dob, CURDATE()) < 18 THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20012, MESSAGE_TEXT = 'Invalid date of birth';
  END IF;
END$$

-- T3. New booking: eligibility (BR-01), bookable vehicle (BR-03),
--     no double booking (BR-02). A CHECK constraint cannot use NOW()
--     or other tables, so this is done in a trigger (Design Q5).
CREATE TRIGGER trg_booking_before_insert
BEFORE INSERT ON booking
FOR EACH ROW
BEGIN
  DECLARE v_dob     DATE;
  DECLARE v_expiry  DATE;
  DECLARE v_vstatus VARCHAR(12);
  DECLARE v_clash   INT DEFAULT NULL;
  DECLARE v_msg     VARCHAR(128);

  IF NEW.status IN ('BOOKED', 'ONGOING') THEN
    SELECT dob, license_expiry INTO v_dob, v_expiry FROM customer WHERE customer_id = NEW.customer_id;

    -- BR-01 (a): at least 21 years old on the pickup date
    IF TIMESTAMPDIFF(YEAR, v_dob, NEW.start_date) < 21 THEN
      SET v_msg = CONCAT('Customer must be at least 21 years old on the pickup date (age ',
                         TIMESTAMPDIFF(YEAR, v_dob, NEW.start_date), ')');
      SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20001, MESSAGE_TEXT = v_msg;
    END IF;

    -- BR-01 (b): licence valid for the whole rental
    IF v_expiry < DATE(NEW.end_date) THEN
      SET v_msg = CONCAT('Driving licence expires on ', DATE_FORMAT(v_expiry, '%d-%b-%Y'),
                         ', before the booking ends');
      SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20002, MESSAGE_TEXT = v_msg;
    END IF;

    -- BR-03: vehicles under maintenance or retired cannot be booked
    SELECT status INTO v_vstatus FROM vehicle WHERE vehicle_id = NEW.vehicle_id;
    IF v_vstatus IN ('MAINTENANCE', 'RETIRED') THEN
      SET v_msg = CONCAT('Vehicle ', NEW.vehicle_id, ' is ', v_vstatus, ' and cannot be booked');
      SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20003, MESSAGE_TEXT = v_msg;
    END IF;

    -- BR-02: no overlapping BOOKED / ONGOING booking for the same vehicle
    SELECT MIN(booking_id) INTO v_clash
      FROM booking
     WHERE vehicle_id = NEW.vehicle_id
       AND status IN ('BOOKED', 'ONGOING')
       AND start_date < NEW.end_date
       AND end_date   > NEW.start_date;
    IF v_clash IS NOT NULL THEN
      SET v_msg = CONCAT('Vehicle is already booked for these dates (clashes with booking ', v_clash, ')');
      SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20004, MESSAGE_TEXT = v_msg;
    END IF;
  END IF;
END$$

-- T4. Booking update: status may only move forward
--     (BOOKED -> ONGOING | CANCELLED, ONGOING -> COMPLETED),
--     and changed dates / vehicle are re-checked for overlap (BR-02)
CREATE TRIGGER trg_booking_before_update
BEFORE UPDATE ON booking
FOR EACH ROW
BEGIN
  DECLARE v_clash INT DEFAULT NULL;
  DECLARE v_msg   VARCHAR(128);

  IF NEW.status <> OLD.status AND NOT (
       (OLD.status = 'BOOKED'  AND NEW.status IN ('ONGOING', 'CANCELLED')) OR
       (OLD.status = 'ONGOING' AND NEW.status = 'COMPLETED')) THEN
    SET v_msg = CONCAT('Invalid booking status change ', OLD.status, ' -> ', NEW.status);
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20005, MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.status IN ('BOOKED', 'ONGOING') AND
     (NEW.vehicle_id <> OLD.vehicle_id OR NEW.start_date <> OLD.start_date OR NEW.end_date <> OLD.end_date) THEN
    SELECT MIN(booking_id) INTO v_clash
      FROM booking
     WHERE vehicle_id = NEW.vehicle_id
       AND booking_id <> NEW.booking_id
       AND status IN ('BOOKED', 'ONGOING')
       AND start_date < NEW.end_date
       AND end_date   > NEW.start_date;
    IF v_clash IS NOT NULL THEN
      SET v_msg = CONCAT('Vehicle is already booked for these dates (clashes with booking ', v_clash, ')');
      SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20004, MESSAGE_TEXT = v_msg;
    END IF;
  END IF;
END$$

-- T5-T7. Audit trail: every insert / status change / delete on BOOKING
CREATE TRIGGER trg_booking_after_insert
AFTER INSERT ON booking
FOR EACH ROW
  INSERT INTO booking_audit (booking_id, action, old_status, new_status, changed_by)
  VALUES (NEW.booking_id, 'INSERT', NULL, NEW.status, USER())$$

CREATE TRIGGER trg_booking_after_update
AFTER UPDATE ON booking
FOR EACH ROW
BEGIN
  IF NOT (OLD.status <=> NEW.status) THEN
    INSERT INTO booking_audit (booking_id, action, old_status, new_status, changed_by)
    VALUES (NEW.booking_id, 'UPDATE', OLD.status, NEW.status, USER());
  END IF;
END$$

CREATE TRIGGER trg_booking_after_delete
AFTER DELETE ON booking
FOR EACH ROW
  INSERT INTO booking_audit (booking_id, action, old_status, new_status, changed_by)
  VALUES (OLD.booking_id, 'DELETE', OLD.status, NULL, USER())$$

-- T8. A vehicle's odometer can never go backwards (supports BR-08)
CREATE TRIGGER trg_vehicle_before_update
BEFORE UPDATE ON vehicle
FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(128);
  IF NEW.odometer < OLD.odometer THEN
    SET v_msg = CONCAT('Odometer cannot decrease (', OLD.odometer, ' -> ', NEW.odometer, ')');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20006, MESSAGE_TEXT = v_msg;
  END IF;
END$$

-- T9. A rented or retired vehicle cannot be sent for maintenance
CREATE TRIGGER trg_maint_before_insert
BEFORE INSERT ON maintenance
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(12);
  DECLARE v_msg    VARCHAR(128);
  IF NEW.maint_status IN ('SCHEDULED', 'IN_PROGRESS') THEN
    SELECT status INTO v_status FROM vehicle WHERE vehicle_id = NEW.vehicle_id;
    IF v_status IN ('RENTED', 'RETIRED') THEN
      SET v_msg = CONCAT('Vehicle ', NEW.vehicle_id, ' is ', v_status, ' and cannot be sent for maintenance');
      SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20007, MESSAGE_TEXT = v_msg;
    END IF;
  END IF;
END$$

-- T10. Opening a maintenance job takes the vehicle off the road (BR-03)
CREATE TRIGGER trg_maint_after_insert
AFTER INSERT ON maintenance
FOR EACH ROW
BEGIN
  IF NEW.maint_status IN ('SCHEDULED', 'IN_PROGRESS') THEN
    UPDATE vehicle SET status = 'MAINTENANCE'
     WHERE vehicle_id = NEW.vehicle_id AND status = 'AVAILABLE';
  END IF;
END$$

-- T11. Closing the job releases the vehicle back to the fleet (FR-09)
CREATE TRIGGER trg_maint_after_update
AFTER UPDATE ON maintenance
FOR EACH ROW
BEGIN
  IF NEW.maint_status = 'DONE' AND OLD.maint_status <> 'DONE' THEN
    UPDATE vehicle SET status = 'AVAILABLE'
     WHERE vehicle_id = NEW.vehicle_id AND status = 'MAINTENANCE';
  ELSEIF NEW.maint_status IN ('SCHEDULED', 'IN_PROGRESS') THEN
    UPDATE vehicle SET status = 'MAINTENANCE'
     WHERE vehicle_id = NEW.vehicle_id AND status = 'AVAILABLE';
  END IF;
END$$

-- T12. Payments: only a REFUND on a cancelled booking, and a REFUND
--      only on a cancelled or completed booking
CREATE TRIGGER trg_payment_before_insert
BEFORE INSERT ON payment
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(12);
  DECLARE v_msg    VARCHAR(128);
  SELECT status INTO v_status FROM booking WHERE booking_id = NEW.booking_id;
  IF v_status = 'CANCELLED' AND NEW.payment_type <> 'REFUND' THEN
    SET v_msg = CONCAT('Booking ', NEW.booking_id, ' is cancelled; only a REFUND can be recorded');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20008, MESSAGE_TEXT = v_msg;
  END IF;
  IF NEW.payment_type = 'REFUND' AND v_status NOT IN ('CANCELLED', 'COMPLETED') THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20008,
      MESSAGE_TEXT = 'A REFUND can only be recorded on a cancelled or completed booking';
  END IF;
  SET NEW.payment_date = COALESCE(NEW.payment_date, NOW());
END$$

DELIMITER ;

SELECT 'Triggers created' AS status;
