-- =====================================================================
-- DriveEase - Vehicle Rental Management System
-- 01_tables.sql  :  sequences, tables and constraints (Review I schema)
-- Run as DRIVEEASE. Safe to re-run: existing objects are dropped first.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON

PROMPT Dropping old objects (errors ignored if they do not exist)...
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
             WHERE table_name IN ('BOOKING_AUDIT','PAYMENT','MAINTENANCE','BOOKING',
                                  'EMPLOYEE','CUSTOMER','VEHICLE',
                                  'VEHICLE_CATEGORY','BRANCH')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
  FOR s IN (SELECT sequence_name FROM user_sequences
             WHERE sequence_name LIKE 'SEQ\_%' ESCAPE '\') LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- Sequences (surrogate keys - see Design Decision Q6)
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_branch      START WITH 1      INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_category    START WITH 1      INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_vehicle     START WITH 101    INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_customer    START WITH 1001   INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_employee    START WITH 501    INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_booking     START WITH 5001   INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_payment     START WITH 90001  INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_maintenance START WITH 701    INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_audit       START WITH 1      INCREMENT BY 1 NOCACHE;

-- ---------------------------------------------------------------------
-- 1. BRANCH
-- ---------------------------------------------------------------------
CREATE TABLE branch (
  branch_id    NUMBER(4)     DEFAULT seq_branch.NEXTVAL,
  branch_name  VARCHAR2(50)  NOT NULL,
  city         VARCHAR2(30)  NOT NULL,
  address      VARCHAR2(120) NOT NULL,
  phone        VARCHAR2(10)  NOT NULL,
  email        VARCHAR2(60),
  CONSTRAINT pk_branch       PRIMARY KEY (branch_id),
  CONSTRAINT uq_branch_name  UNIQUE (branch_name),
  CONSTRAINT uq_branch_phone UNIQUE (phone),
  CONSTRAINT uq_branch_email UNIQUE (email),
  CONSTRAINT ck_branch_phone CHECK (LENGTH(phone) = 10 AND REGEXP_LIKE(phone, '^[0-9]+$'))
);

-- ---------------------------------------------------------------------
-- 2. VEHICLE_CATEGORY
-- ---------------------------------------------------------------------
CREATE TABLE vehicle_category (
  category_id      NUMBER(3)    DEFAULT seq_category.NEXTVAL,
  category_name    VARCHAR2(30) NOT NULL,
  daily_rate       NUMBER(8,2)  NOT NULL,
  late_fee_per_hr  NUMBER(7,2)  DEFAULT 100,
  seating_capacity NUMBER(2),
  security_deposit NUMBER(8,2)  DEFAULT 2000,
  CONSTRAINT pk_category        PRIMARY KEY (category_id),
  CONSTRAINT uq_category_name   UNIQUE (category_name),
  CONSTRAINT ck_category_rate   CHECK (daily_rate > 0),
  CONSTRAINT ck_category_late   CHECK (late_fee_per_hr >= 0),
  CONSTRAINT ck_category_seats  CHECK (seating_capacity BETWEEN 1 AND 15),
  CONSTRAINT ck_category_dep    CHECK (security_deposit >= 0)
);

-- ---------------------------------------------------------------------
-- 3. VEHICLE
-- ---------------------------------------------------------------------
CREATE TABLE vehicle (
  vehicle_id   NUMBER(5)    DEFAULT seq_vehicle.NEXTVAL,
  reg_number   VARCHAR2(12) NOT NULL,
  brand        VARCHAR2(30) NOT NULL,
  model        VARCHAR2(30) NOT NULL,
  mfg_year     NUMBER(4),
  fuel_type    VARCHAR2(10) NOT NULL,
  transmission VARCHAR2(10) DEFAULT 'MANUAL',
  odometer     NUMBER(7)    DEFAULT 0,
  status       VARCHAR2(12) DEFAULT 'AVAILABLE',
  category_id  NUMBER(3)    NOT NULL,
  branch_id    NUMBER(4)    NOT NULL,
  CONSTRAINT pk_vehicle        PRIMARY KEY (vehicle_id),
  CONSTRAINT uq_vehicle_reg    UNIQUE (reg_number),
  CONSTRAINT ck_vehicle_year   CHECK (mfg_year >= 2010),
  CONSTRAINT ck_vehicle_fuel   CHECK (fuel_type IN ('PETROL','DIESEL','CNG','ELECTRIC')),
  CONSTRAINT ck_vehicle_trans  CHECK (transmission IN ('MANUAL','AUTOMATIC')),
  CONSTRAINT ck_vehicle_odo    CHECK (odometer >= 0),
  CONSTRAINT ck_vehicle_status CHECK (status IN ('AVAILABLE','RENTED','MAINTENANCE','RETIRED')),
  CONSTRAINT fk_vehicle_cat    FOREIGN KEY (category_id) REFERENCES vehicle_category (category_id),
  CONSTRAINT fk_vehicle_branch FOREIGN KEY (branch_id)   REFERENCES branch (branch_id)
);

-- ---------------------------------------------------------------------
-- 4. CUSTOMER   (age >= 21 and licence validity are enforced by triggers)
-- ---------------------------------------------------------------------
CREATE TABLE customer (
  customer_id    NUMBER(6)     DEFAULT seq_customer.NEXTVAL,
  name           VARCHAR2(50)  NOT NULL,
  phone          VARCHAR2(10)  NOT NULL,
  email          VARCHAR2(60),
  license_no     VARCHAR2(16)  NOT NULL,
  license_expiry DATE          NOT NULL,
  dob            DATE          NOT NULL,
  address        VARCHAR2(120),
  registered_on  DATE          DEFAULT SYSDATE,
  CONSTRAINT pk_customer         PRIMARY KEY (customer_id),
  CONSTRAINT uq_customer_phone   UNIQUE (phone),
  CONSTRAINT uq_customer_email   UNIQUE (email),
  CONSTRAINT uq_customer_license UNIQUE (license_no),
  CONSTRAINT ck_customer_phone   CHECK (LENGTH(phone) = 10 AND REGEXP_LIKE(phone, '^[0-9]+$'))
);

-- ---------------------------------------------------------------------
-- 5. EMPLOYEE
-- ---------------------------------------------------------------------
CREATE TABLE employee (
  emp_id    NUMBER(5)    DEFAULT seq_employee.NEXTVAL,
  name      VARCHAR2(50) NOT NULL,
  role      VARCHAR2(15) NOT NULL,
  phone     VARCHAR2(10) NOT NULL,
  email     VARCHAR2(60),
  salary    NUMBER(9,2),
  hire_date DATE         DEFAULT SYSDATE,
  branch_id NUMBER(4)    NOT NULL,
  CONSTRAINT pk_employee        PRIMARY KEY (emp_id),
  CONSTRAINT uq_employee_phone  UNIQUE (phone),
  CONSTRAINT uq_employee_email  UNIQUE (email),
  CONSTRAINT ck_employee_role   CHECK (role IN ('MANAGER','AGENT','MECHANIC','CASHIER')),
  CONSTRAINT ck_employee_salary CHECK (salary > 0),
  CONSTRAINT ck_employee_phone  CHECK (LENGTH(phone) = 10 AND REGEXP_LIKE(phone, '^[0-9]+$')),
  CONSTRAINT fk_employee_branch FOREIGN KEY (branch_id) REFERENCES branch (branch_id)
);

-- ---------------------------------------------------------------------
-- 6. BOOKING
-- ---------------------------------------------------------------------
CREATE TABLE booking (
  booking_id         NUMBER(7)    DEFAULT seq_booking.NEXTVAL,
  customer_id        NUMBER(6)    NOT NULL,
  vehicle_id         NUMBER(5)    NOT NULL,
  emp_id             NUMBER(5)    NOT NULL,
  pickup_branch_id   NUMBER(4)    NOT NULL,
  return_branch_id   NUMBER(4)    NOT NULL,
  booking_date       DATE         DEFAULT SYSDATE,
  start_date         DATE         NOT NULL,
  end_date           DATE         NOT NULL,
  actual_return_date DATE,
  start_odometer     NUMBER(7),
  end_odometer       NUMBER(7),
  status             VARCHAR2(12) DEFAULT 'BOOKED',
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
);

-- ---------------------------------------------------------------------
-- 7. PAYMENT
-- ---------------------------------------------------------------------
CREATE TABLE payment (
  payment_id   NUMBER(8)    DEFAULT seq_payment.NEXTVAL,
  booking_id   NUMBER(7)    NOT NULL,
  amount       NUMBER(9,2)  NOT NULL,
  payment_date DATE         DEFAULT SYSDATE,
  method       VARCHAR2(12) NOT NULL,
  payment_type VARCHAR2(10) NOT NULL,
  txn_status   VARCHAR2(10) DEFAULT 'SUCCESS',
  CONSTRAINT pk_payment         PRIMARY KEY (payment_id),
  CONSTRAINT fk_payment_booking FOREIGN KEY (booking_id) REFERENCES booking (booking_id) ON DELETE CASCADE,
  CONSTRAINT ck_payment_amount  CHECK (amount > 0),
  CONSTRAINT ck_payment_method  CHECK (method IN ('CASH','CARD','UPI','NETBANKING')),
  CONSTRAINT ck_payment_type    CHECK (payment_type IN ('ADVANCE','FINAL','LATE_FEE','REFUND')),
  CONSTRAINT ck_payment_status  CHECK (txn_status IN ('SUCCESS','PENDING','FAILED'))
);

-- ---------------------------------------------------------------------
-- 8. MAINTENANCE
-- ---------------------------------------------------------------------
CREATE TABLE maintenance (
  maint_id     NUMBER(6)     DEFAULT seq_maintenance.NEXTVAL,
  vehicle_id   NUMBER(5)     NOT NULL,
  service_date DATE          DEFAULT SYSDATE,
  service_type VARCHAR2(20)  NOT NULL,
  description  VARCHAR2(200),
  cost         NUMBER(9,2)   DEFAULT 0,
  maint_status VARCHAR2(12)  DEFAULT 'SCHEDULED',
  CONSTRAINT pk_maintenance       PRIMARY KEY (maint_id),
  CONSTRAINT fk_maint_vehicle     FOREIGN KEY (vehicle_id) REFERENCES vehicle (vehicle_id),
  CONSTRAINT ck_maint_type        CHECK (service_type IN ('GENERAL','REPAIR','TYRE','ACCIDENT','INSURANCE')),
  CONSTRAINT ck_maint_cost        CHECK (cost >= 0),
  CONSTRAINT ck_maint_status      CHECK (maint_status IN ('SCHEDULED','IN_PROGRESS','DONE'))
);

-- ---------------------------------------------------------------------
-- Supporting table: audit trail of every booking change (filled by trigger)
-- ---------------------------------------------------------------------
CREATE TABLE booking_audit (
  audit_id    NUMBER(8)    DEFAULT seq_audit.NEXTVAL,
  booking_id  NUMBER(7),
  action      VARCHAR2(10),
  old_status  VARCHAR2(12),
  new_status  VARCHAR2(12),
  changed_by  VARCHAR2(30) DEFAULT USER,
  changed_on  DATE         DEFAULT SYSDATE,
  CONSTRAINT pk_booking_audit PRIMARY KEY (audit_id)
);

-- Indexes on foreign keys used by searches and reports
CREATE INDEX ix_vehicle_branch   ON vehicle (branch_id);
CREATE INDEX ix_vehicle_category ON vehicle (category_id);
CREATE INDEX ix_booking_vehicle  ON booking (vehicle_id, start_date, end_date);
CREATE INDEX ix_booking_customer ON booking (customer_id);
CREATE INDEX ix_payment_booking  ON payment (booking_id);
CREATE INDEX ix_maint_vehicle    ON maintenance (vehicle_id);

PROMPT Tables created.
