-- =====================================================================
-- DriveEase - 03_procedures.sql : stand-alone PL/SQL PROCEDURES
-- Master-data operations (FR-01, FR-02, FR-10).
-- Procedures do NOT commit: the caller (web app / SQL Developer user)
-- commits, so several calls can form one transaction. On error each
-- procedure rolls back its own work to a savepoint and re-raises.
-- =====================================================================
SET DEFINE OFF

-- P1. Register a customer (FR-01)
CREATE OR REPLACE PROCEDURE sp_register_customer (
  p_name           IN  customer.name%TYPE,
  p_phone          IN  customer.phone%TYPE,
  p_email          IN  customer.email%TYPE,
  p_license_no     IN  customer.license_no%TYPE,
  p_license_expiry IN  customer.license_expiry%TYPE,
  p_dob            IN  customer.dob%TYPE,
  p_address        IN  customer.address%TYPE,
  p_customer_id    OUT customer.customer_id%TYPE
)
IS
BEGIN
  SAVEPOINT sp_register_customer;
  INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address)
  VALUES (TRIM(p_name), p_phone, LOWER(p_email), UPPER(p_license_no),
          p_license_expiry, p_dob, p_address)
  RETURNING customer_id INTO p_customer_id;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    ROLLBACK TO sp_register_customer;
    RAISE_APPLICATION_ERROR(-20020, 'A customer with this phone, email or licence number already exists');
  WHEN OTHERS THEN
    ROLLBACK TO sp_register_customer;
    RAISE;
END sp_register_customer;
/

-- P2. Add a branch (FR-10)
CREATE OR REPLACE PROCEDURE sp_add_branch (
  p_name      IN  branch.branch_name%TYPE,
  p_city      IN  branch.city%TYPE,
  p_address   IN  branch.address%TYPE,
  p_phone     IN  branch.phone%TYPE,
  p_email     IN  branch.email%TYPE,
  p_branch_id OUT branch.branch_id%TYPE
)
IS
BEGIN
  INSERT INTO branch (branch_name, city, address, phone, email)
  VALUES (TRIM(p_name), INITCAP(TRIM(p_city)), p_address, p_phone, LOWER(p_email))
  RETURNING branch_id INTO p_branch_id;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    RAISE_APPLICATION_ERROR(-20021, 'A branch with this name, phone or email already exists');
END sp_add_branch;
/

-- P3. Add an employee to a branch (FR-10)
CREATE OR REPLACE PROCEDURE sp_add_employee (
  p_name      IN  employee.name%TYPE,
  p_role      IN  employee.role%TYPE,
  p_phone     IN  employee.phone%TYPE,
  p_email     IN  employee.email%TYPE,
  p_salary    IN  employee.salary%TYPE,
  p_branch_id IN  employee.branch_id%TYPE,
  p_emp_id    OUT employee.emp_id%TYPE
)
IS
BEGIN
  INSERT INTO employee (name, role, phone, email, salary, branch_id)
  VALUES (TRIM(p_name), UPPER(p_role), p_phone, LOWER(p_email), p_salary, p_branch_id)
  RETURNING emp_id INTO p_emp_id;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    RAISE_APPLICATION_ERROR(-20022, 'An employee with this phone or email already exists');
END sp_add_employee;
/

-- P4. Add a vehicle to the fleet (FR-02)
CREATE OR REPLACE PROCEDURE sp_add_vehicle (
  p_reg_number   IN  vehicle.reg_number%TYPE,
  p_brand        IN  vehicle.brand%TYPE,
  p_model        IN  vehicle.model%TYPE,
  p_mfg_year     IN  vehicle.mfg_year%TYPE,
  p_fuel_type    IN  vehicle.fuel_type%TYPE,
  p_transmission IN  vehicle.transmission%TYPE,
  p_odometer     IN  vehicle.odometer%TYPE,
  p_category_id  IN  vehicle.category_id%TYPE,
  p_branch_id    IN  vehicle.branch_id%TYPE,
  p_vehicle_id   OUT vehicle.vehicle_id%TYPE
)
IS
BEGIN
  INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission,
                       odometer, category_id, branch_id)
  VALUES (UPPER(REPLACE(p_reg_number, ' ', '')), p_brand, p_model, p_mfg_year,
          UPPER(p_fuel_type), UPPER(NVL(p_transmission, 'MANUAL')),
          NVL(p_odometer, 0), p_category_id, p_branch_id)
  RETURNING vehicle_id INTO p_vehicle_id;
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    RAISE_APPLICATION_ERROR(-20023, 'Registration number ' || p_reg_number || ' already exists');
END sp_add_vehicle;
/

-- P5. Retire a vehicle (FR-02). A vehicle with open bookings cannot be retired.
CREATE OR REPLACE PROCEDURE sp_retire_vehicle (
  p_vehicle_id IN vehicle.vehicle_id%TYPE
)
IS
  v_open NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_open
    FROM booking
   WHERE vehicle_id = p_vehicle_id
     AND status IN ('BOOKED', 'ONGOING');
  IF v_open > 0 THEN
    RAISE_APPLICATION_ERROR(-20024, 'Vehicle ' || p_vehicle_id || ' has ' || v_open ||
                                    ' open booking(s) and cannot be retired');
  END IF;

  UPDATE vehicle SET status = 'RETIRED' WHERE vehicle_id = p_vehicle_id;
  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20025, 'Vehicle ' || p_vehicle_id || ' does not exist');
  END IF;
END sp_retire_vehicle;
/

-- P6. Change the price of a category (a single-row update thanks to 3NF, Q1)
CREATE OR REPLACE PROCEDURE sp_update_category_rate (
  p_category_id IN vehicle_category.category_id%TYPE,
  p_daily_rate  IN vehicle_category.daily_rate%TYPE,
  p_late_fee    IN vehicle_category.late_fee_per_hr%TYPE DEFAULT NULL
)
IS
BEGIN
  UPDATE vehicle_category
     SET daily_rate      = p_daily_rate,
         late_fee_per_hr = NVL(p_late_fee, late_fee_per_hr)
   WHERE category_id = p_category_id;
  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20026, 'Category ' || p_category_id || ' does not exist');
  END IF;
END sp_update_category_rate;
/

PROMPT Procedures created.
