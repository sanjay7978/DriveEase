-- =====================================================================
-- DriveEase (MySQL 8) - 03_procedures.sql : stand-alone PROCEDURES
-- Master-data operations (FR-01, FR-02, FR-10).
-- Business errors are raised with SIGNAL and an error number 200xx.
-- =====================================================================
USE driveease;

DROP PROCEDURE IF EXISTS sp_register_customer;
DROP PROCEDURE IF EXISTS sp_add_branch;
DROP PROCEDURE IF EXISTS sp_add_employee;
DROP PROCEDURE IF EXISTS sp_add_vehicle;
DROP PROCEDURE IF EXISTS sp_retire_vehicle;
DROP PROCEDURE IF EXISTS sp_update_category_rate;

DELIMITER $$

-- P1. Register a customer (FR-01)
CREATE PROCEDURE sp_register_customer (
  IN  p_name           VARCHAR(50),
  IN  p_phone          VARCHAR(10),
  IN  p_email          VARCHAR(60),
  IN  p_license_no     VARCHAR(16),
  IN  p_license_expiry DATE,
  IN  p_dob            DATE,
  IN  p_address        VARCHAR(120),
  OUT p_customer_id    INT
)
BEGIN
  DECLARE EXIT HANDLER FOR 1062            -- duplicate key on a UNIQUE column
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20020,
      MESSAGE_TEXT = 'A customer with this phone, email or licence number already exists';

  INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address)
  VALUES (TRIM(p_name), p_phone, LOWER(NULLIF(p_email, '')), UPPER(p_license_no),
          p_license_expiry, p_dob, NULLIF(p_address, ''));
  SET p_customer_id = LAST_INSERT_ID();
END$$

-- P2. Add a branch (FR-10)
CREATE PROCEDURE sp_add_branch (
  IN  p_name      VARCHAR(50),
  IN  p_city      VARCHAR(30),
  IN  p_address   VARCHAR(120),
  IN  p_phone     VARCHAR(10),
  IN  p_email     VARCHAR(60),
  OUT p_branch_id INT
)
BEGIN
  DECLARE EXIT HANDLER FOR 1062
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20021,
      MESSAGE_TEXT = 'A branch with this name, phone or email already exists';

  INSERT INTO branch (branch_name, city, address, phone, email)
  VALUES (TRIM(p_name), TRIM(p_city), p_address, p_phone, LOWER(NULLIF(p_email, '')));
  SET p_branch_id = LAST_INSERT_ID();
END$$

-- P3. Add an employee (FR-10)
CREATE PROCEDURE sp_add_employee (
  IN  p_name      VARCHAR(50),
  IN  p_role      VARCHAR(15),
  IN  p_phone     VARCHAR(10),
  IN  p_email     VARCHAR(60),
  IN  p_salary    DECIMAL(9,2),
  IN  p_branch_id INT,
  OUT p_emp_id    INT
)
BEGIN
  DECLARE EXIT HANDLER FOR 1062
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20022,
      MESSAGE_TEXT = 'An employee with this phone or email already exists';

  INSERT INTO employee (name, role, phone, email, salary, branch_id)
  VALUES (TRIM(p_name), UPPER(p_role), p_phone, LOWER(NULLIF(p_email, '')), p_salary, p_branch_id);
  SET p_emp_id = LAST_INSERT_ID();
END$$

-- P4. Add a vehicle to the fleet (FR-02)
CREATE PROCEDURE sp_add_vehicle (
  IN  p_reg_number   VARCHAR(12),
  IN  p_brand        VARCHAR(30),
  IN  p_model        VARCHAR(30),
  IN  p_mfg_year     INT,
  IN  p_fuel_type    VARCHAR(10),
  IN  p_transmission VARCHAR(10),
  IN  p_odometer     INT,
  IN  p_category_id  INT,
  IN  p_branch_id    INT,
  OUT p_vehicle_id   INT
)
BEGIN
  DECLARE EXIT HANDLER FOR 1062
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20023,
      MESSAGE_TEXT = 'This registration number already exists';

  INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission,
                       odometer, category_id, branch_id)
  VALUES (UPPER(REPLACE(p_reg_number, ' ', '')), p_brand, p_model, p_mfg_year,
          UPPER(p_fuel_type), UPPER(COALESCE(p_transmission, 'MANUAL')),
          COALESCE(p_odometer, 0), p_category_id, p_branch_id);
  SET p_vehicle_id = LAST_INSERT_ID();
END$$

-- P5. Retire a vehicle (FR-02). A vehicle with open bookings cannot be retired.
CREATE PROCEDURE sp_retire_vehicle (IN p_vehicle_id INT)
BEGIN
  DECLARE v_open INT;
  DECLARE v_msg  VARCHAR(128);

  SELECT COUNT(*) INTO v_open
    FROM booking
   WHERE vehicle_id = p_vehicle_id AND status IN ('BOOKED', 'ONGOING');
  IF v_open > 0 THEN
    SET v_msg = CONCAT('Vehicle ', p_vehicle_id, ' has ', v_open, ' open booking(s) and cannot be retired');
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20024, MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE vehicle SET status = 'RETIRED' WHERE vehicle_id = p_vehicle_id;
  IF ROW_COUNT() = 0 THEN                                   -- implicit cursor attribute
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20025, MESSAGE_TEXT = 'Vehicle does not exist';
  END IF;
END$$

-- P6. Change the price of a category - a single-row update thanks to 3NF (Q1)
CREATE PROCEDURE sp_update_category_rate (
  IN p_category_id INT,
  IN p_daily_rate  DECIMAL(8,2),
  IN p_late_fee    DECIMAL(7,2)
)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vehicle_category WHERE category_id = p_category_id) THEN
    SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20026, MESSAGE_TEXT = 'Category does not exist';
  END IF;
  UPDATE vehicle_category
     SET daily_rate      = p_daily_rate,
         late_fee_per_hr = COALESCE(p_late_fee, late_fee_per_hr)
   WHERE category_id = p_category_id;
END$$

DELIMITER ;

SELECT 'Procedures created' AS status;
