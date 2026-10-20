-- =====================================================================
-- DriveEase (MySQL 8) - 01_tables.sql : tables, keys and constraints
-- Implements the Review I relational schema. Safe to re-run.
-- =====================================================================
USE driveease;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS booking_audit, payment, maintenance, booking, employee,
                     customer, vehicle, vehicle_category, branch;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. BRANCH
-- ---------------------------------------------------------------------
CREATE TABLE branch (
  branch_id    SMALLINT      NOT NULL AUTO_INCREMENT,
  branch_name  VARCHAR(50)   NOT NULL,
  city         VARCHAR(30)   NOT NULL,
  address      VARCHAR(120)  NOT NULL,
  phone        VARCHAR(10)   NOT NULL,
  email        VARCHAR(60),
  CONSTRAINT pk_branch       PRIMARY KEY (branch_id),
  CONSTRAINT uq_branch_name  UNIQUE (branch_name),
  CONSTRAINT uq_branch_phone UNIQUE (phone),
  CONSTRAINT uq_branch_email UNIQUE (email),
  CONSTRAINT ck_branch_phone CHECK (phone REGEXP '^[0-9]{10}$')
) ENGINE = InnoDB AUTO_INCREMENT = 1;

-- ---------------------------------------------------------------------
-- 2. VEHICLE_CATEGORY
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_category (
  category_id      SMALLINT      NOT NULL AUTO_INCREMENT,
  category_name    VARCHAR(30)   NOT NULL,
  daily_rate       DECIMAL(8,2)  NOT NULL,
  late_fee_per_hr  DECIMAL(7,2)  DEFAULT 100,
  seating_capacity TINYINT,
  security_deposit DECIMAL(8,2)  DEFAULT 2000,
  CONSTRAINT pk_category       PRIMARY KEY (category_id),
  CONSTRAINT uq_category_name  UNIQUE (category_name),
  CONSTRAINT ck_category_rate  CHECK (daily_rate > 0),
  CONSTRAINT ck_category_late  CHECK (late_fee_per_hr >= 0),
  CONSTRAINT ck_category_seats CHECK (seating_capacity BETWEEN 1 AND 15),
  CONSTRAINT ck_category_dep   CHECK (security_deposit >= 0)
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 3. VEHICLE
-- ---------------------------------------------------------------------
CREATE TABLE vehicle (
  vehicle_id   INT          NOT NULL AUTO_INCREMENT,
  reg_number   VARCHAR(12)  NOT NULL,
  brand        VARCHAR(30)  NOT NULL,
  model        VARCHAR(30)  NOT NULL,
  mfg_year     SMALLINT,
  fuel_type    VARCHAR(10)  NOT NULL,
  transmission VARCHAR(10)  DEFAULT 'MANUAL',
  odometer     INT          DEFAULT 0,
  status       VARCHAR(12)  DEFAULT 'AVAILABLE',
  category_id  SMALLINT     NOT NULL,
  branch_id    SMALLINT     NOT NULL,
  CONSTRAINT pk_vehicle        PRIMARY KEY (vehicle_id),
  CONSTRAINT uq_vehicle_reg    UNIQUE (reg_number),
  CONSTRAINT ck_vehicle_year   CHECK (mfg_year >= 2010),
  CONSTRAINT ck_vehicle_fuel   CHECK (fuel_type IN ('PETROL','DIESEL','CNG','ELECTRIC')),
  CONSTRAINT ck_vehicle_trans  CHECK (transmission IN ('MANUAL','AUTOMATIC')),
  CONSTRAINT ck_vehicle_odo    CHECK (odometer >= 0),
  CONSTRAINT ck_vehicle_status CHECK (status IN ('AVAILABLE','RENTED','MAINTENANCE','RETIRED')),
  CONSTRAINT fk_vehicle_cat    FOREIGN KEY (category_id) REFERENCES vehicle_category (category_id),
  CONSTRAINT fk_vehicle_branch FOREIGN KEY (branch_id)   REFERENCES branch (branch_id)
) ENGINE = InnoDB AUTO_INCREMENT = 101;

-- ---------------------------------------------------------------------
-- 4. CUSTOMER  (age >= 21 and licence validity are enforced by triggers,
--              because a CHECK constraint cannot use NOW())
-- ---------------------------------------------------------------------
CREATE TABLE customer (
  customer_id    INT           NOT NULL AUTO_INCREMENT,
  name           VARCHAR(50)   NOT NULL,
  phone          VARCHAR(10)   NOT NULL,
  email          VARCHAR(60),
  license_no     VARCHAR(16)   NOT NULL,
  license_expiry DATE          NOT NULL,
  dob            DATE          NOT NULL,
  address        VARCHAR(120),
  registered_on  DATE          DEFAULT (CURRENT_DATE),
  CONSTRAINT pk_customer         PRIMARY KEY (customer_id),
  CONSTRAINT uq_customer_phone   UNIQUE (phone),
  CONSTRAINT uq_customer_email   UNIQUE (email),
  CONSTRAINT uq_customer_license UNIQUE (license_no),
  CONSTRAINT ck_customer_phone   CHECK (phone REGEXP '^[0-9]{10}$')
) ENGINE = InnoDB AUTO_INCREMENT = 1001;

-- ---------------------------------------------------------------------
-- 5. EMPLOYEE
-- ---------------------------------------------------------------------
CREATE TABLE employee (
  emp_id    INT           NOT NULL AUTO_INCREMENT,
  name      VARCHAR(50)   NOT NULL,
  role      VARCHAR(15)   NOT NULL,
  phone     VARCHAR(10)   NOT NULL,
  email     VARCHAR(60),
  salary    DECIMAL(9,2),
  hire_date DATE          DEFAULT (CURRENT_DATE),
  branch_id SMALLINT      NOT NULL,
  CONSTRAINT pk_employee        PRIMARY KEY (emp_id),
  CONSTRAINT uq_employee_phone  UNIQUE (phone),
  CONSTRAINT uq_employee_email  UNIQUE (email),
  CONSTRAINT ck_employee_role   CHECK (role IN ('MANAGER','AGENT','MECHANIC','CASHIER')),
  CONSTRAINT ck_employee_salary CHECK (salary > 0),
  CONSTRAINT ck_employee_phone  CHECK (phone REGEXP '^[0-9]{10}$'),
  CONSTRAINT fk_employee_branch FOREIGN KEY (branch_id) REFERENCES branch (branch_id)
) ENGINE = InnoDB AUTO_INCREMENT = 501;

-- ---------------------------------------------------------------------
-- 6. BOOKING
-- ---------------------------------------------------------------------
CREATE TABLE booking (
  booking_id         INT          NOT NULL AUTO_INCREMENT,
  customer_id        INT          NOT NULL,
  vehicle_id         INT          NOT NULL,
  emp_id             INT          NOT NULL,
  pickup_branch_id   SMALLINT     NOT NULL,
  return_branch_id   SMALLINT     NOT NULL,
  booking_date       DATETIME     DEFAULT CURRENT_TIMESTAMP,
  start_date         DATETIME     NOT NULL,
  end_date           DATETIME     NOT NULL,
  actual_return_date DATETIME,
  start_odometer     INT,
  end_odometer       INT,
  status             VARCHAR(12)  DEFAULT 'BOOKED',
  CONSTRAINT pk_booking          PRIMARY KEY (booking_id),
  CONSTRAINT fk_booking_customer FOREIGN KEY (customer_id)      REFERENCES customer (customer_id),
  CONSTRAINT fk_booking_vehicle  FOREIGN KEY (vehicle_id)       REFERENCES vehicle (vehicle_id),
  CONSTRAINT fk_booking_employee FOREIGN KEY (emp_id)           REFERENCES employee (emp_id),
  CONSTRAINT fk_booking_pickup   FOREIGN KEY (pickup_branch_id) REFERENCES branch (branch_id),
  CONSTRAINT fk_booking_return   FOREIGN KEY (return_branch_id) REFERENCES branch (branch_id),
  CONSTRAINT ck_booking_status   CHECK (status IN ('BOOKED','ONGOING','COMPLETED','CANCELLED')),
  CONSTRAINT ck_booking_dates    CHECK (end_date > start_date),
  CONSTRAINT ck_booking_return   CHECK (actual_return_date >= start_date),
  CONSTRAINT ck_booking_odometer CHECK (end_odometer >= start_odometer)          -- BR-08
) ENGINE = InnoDB AUTO_INCREMENT = 5001;

-- ---------------------------------------------------------------------
-- 7. PAYMENT
-- ---------------------------------------------------------------------
CREATE TABLE payment (
  payment_id   INT           NOT NULL AUTO_INCREMENT,
  booking_id   INT           NOT NULL,
  amount       DECIMAL(9,2)  NOT NULL,
  payment_date DATETIME      DEFAULT CURRENT_TIMESTAMP,
  method       VARCHAR(12)   NOT NULL,
  payment_type VARCHAR(10)   NOT NULL,
  txn_status   VARCHAR(10)   DEFAULT 'SUCCESS',
  CONSTRAINT pk_payment         PRIMARY KEY (payment_id),
  CONSTRAINT fk_payment_booking FOREIGN KEY (booking_id) REFERENCES booking (booking_id) ON DELETE CASCADE,
  CONSTRAINT ck_payment_amount  CHECK (amount > 0),
  CONSTRAINT ck_payment_method  CHECK (method IN ('CASH','CARD','UPI','NETBANKING')),
  CONSTRAINT ck_payment_type    CHECK (payment_type IN ('ADVANCE','FINAL','LATE_FEE','REFUND')),
  CONSTRAINT ck_payment_status  CHECK (txn_status IN ('SUCCESS','PENDING','FAILED'))
) ENGINE = InnoDB AUTO_INCREMENT = 90001;

-- ---------------------------------------------------------------------
-- 8. MAINTENANCE
-- ---------------------------------------------------------------------
CREATE TABLE maintenance (
  maint_id     INT           NOT NULL AUTO_INCREMENT,
  vehicle_id   INT           NOT NULL,
  service_date DATETIME      DEFAULT CURRENT_TIMESTAMP,
  service_type VARCHAR(20)   NOT NULL,
  description  VARCHAR(200),
  cost         DECIMAL(9,2)  DEFAULT 0,
  maint_status VARCHAR(12)   DEFAULT 'SCHEDULED',
  CONSTRAINT pk_maintenance   PRIMARY KEY (maint_id),
  CONSTRAINT fk_maint_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicle (vehicle_id),
  CONSTRAINT ck_maint_type    CHECK (service_type IN ('GENERAL','REPAIR','TYRE','ACCIDENT','INSURANCE')),
  CONSTRAINT ck_maint_cost    CHECK (cost >= 0),
  CONSTRAINT ck_maint_status  CHECK (maint_status IN ('SCHEDULED','IN_PROGRESS','DONE'))
) ENGINE = InnoDB AUTO_INCREMENT = 701;

-- ---------------------------------------------------------------------
-- Supporting table: audit trail of every booking change (filled by triggers)
-- ---------------------------------------------------------------------
CREATE TABLE booking_audit (
  audit_id    INT          NOT NULL AUTO_INCREMENT,
  booking_id  INT,
  action      VARCHAR(10),
  old_status  VARCHAR(12),
  new_status  VARCHAR(12),
  changed_by  VARCHAR(60)  DEFAULT (CURRENT_USER()),
  changed_on  DATETIME     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_booking_audit PRIMARY KEY (audit_id)
) ENGINE = InnoDB;

-- Indexes used by searches and reports (InnoDB indexes FK columns automatically)
CREATE INDEX ix_booking_vehicle_dates ON booking (vehicle_id, start_date, end_date);
CREATE INDEX ix_payment_date          ON payment (payment_date);

SELECT 'Tables created' AS status;
