-- =====================================================================
-- DriveEase - 06_seed_data.sql : sample data
-- Booking dates are relative to SYSDATE, so the data always contains
-- past (completed), current (ongoing) and future (booked) rentals.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON

-- ---------------- BRANCH (ids 1..5) ----------------
INSERT INTO branch (branch_name, city, address, phone, email) VALUES
  ('DriveEase Katpadi',       'Vellore',   '12 Gandhi Road, Katpadi, Vellore 632007',            '4162243001', 'katpadi@driveease.in');
INSERT INTO branch (branch_name, city, address, phone, email) VALUES
  ('DriveEase T Nagar',       'Chennai',   '45 Usman Road, T Nagar, Chennai 600017',             '4424340002', 'tnagar@driveease.in');
INSERT INTO branch (branch_name, city, address, phone, email) VALUES
  ('DriveEase Chennai Airport','Chennai',  'GST Road, Meenambakkam, Chennai 600027',             '4422560003', 'maa-airport@driveease.in');
INSERT INTO branch (branch_name, city, address, phone, email) VALUES
  ('DriveEase Koramangala',   'Bengaluru', '80 Feet Road, Koramangala 4th Block, Bengaluru 560034','8041120004', 'koramangala@driveease.in');
INSERT INTO branch (branch_name, city, address, phone, email) VALUES
  ('DriveEase Hitech City',   'Hyderabad', 'Plot 7, Madhapur Main Road, Hyderabad 500081',       '4023110005', 'hitech@driveease.in');

-- ---------------- VEHICLE_CATEGORY (ids 1..6) ----------------
INSERT INTO vehicle_category (category_name, daily_rate, late_fee_per_hr, seating_capacity, security_deposit) VALUES ('Hatchback', 1500, 100, 5, 3000);
INSERT INTO vehicle_category (category_name, daily_rate, late_fee_per_hr, seating_capacity, security_deposit) VALUES ('Sedan',     2200, 150, 5, 5000);
INSERT INTO vehicle_category (category_name, daily_rate, late_fee_per_hr, seating_capacity, security_deposit) VALUES ('SUV',       3200, 200, 7, 7000);
INSERT INTO vehicle_category (category_name, daily_rate, late_fee_per_hr, seating_capacity, security_deposit) VALUES ('Luxury',    6500, 400, 5, 15000);
INSERT INTO vehicle_category (category_name, daily_rate, late_fee_per_hr, seating_capacity, security_deposit) VALUES ('Scooter',    500,  40, 2, 1000);
INSERT INTO vehicle_category (category_name, daily_rate, late_fee_per_hr, seating_capacity, security_deposit) VALUES ('Motorbike',  800,  60, 2, 1500);

-- ---------------- VEHICLE (ids 101..120) ----------------
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN23AB1234', 'Maruti',        'Swift',          2022, 'PETROL',   'MANUAL',    24500, 1, 1);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN23CD5678', 'Hyundai',       'i20',            2023, 'PETROL',   'AUTOMATIC', 18200, 1, 1);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN23EF4321', 'Honda',         'City',           2021, 'PETROL',   'AUTOMATIC', 31000, 2, 1);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN23GH8765', 'Mahindra',      'XUV700',         2023, 'DIESEL',   'AUTOMATIC', 15400, 3, 1);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN23JK1111', 'Honda',         'Activa 6G',      2022, 'PETROL',   'AUTOMATIC',  8200, 5, 1);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN09AB2222', 'Toyota',        'Innova Crysta',  2020, 'DIESEL',   'MANUAL',    52000, 3, 2);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN09CD3333', 'Hyundai',       'Verna',          2022, 'PETROL',   'AUTOMATIC', 22000, 2, 2);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN09EF4444', 'Tata',          'Nexon EV',       2024, 'ELECTRIC', 'AUTOMATIC',  9800, 3, 2);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN09GH5555', 'Royal Enfield', 'Classic 350',    2021, 'PETROL',   'MANUAL',    14000, 6, 2);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN22AB6666', 'Mercedes-Benz', 'C-Class',        2023, 'DIESEL',   'AUTOMATIC', 12000, 4, 3);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN22CD7777', 'Maruti',        'Baleno',         2021, 'PETROL',   'MANUAL',    27000, 1, 3);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TN22EF8888', 'Toyota',        'Fortuner',       2020, 'DIESEL',   'AUTOMATIC', 41000, 3, 3);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('KA01AB1212', 'Tata',          'Tiago',          2020, 'CNG',      'MANUAL',    33000, 1, 4);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('KA01CD3434', 'Skoda',         'Slavia',         2024, 'PETROL',   'AUTOMATIC', 11000, 2, 4);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('KA01EF5656', 'BMW',           '3 Series',       2023, 'PETROL',   'AUTOMATIC',  8000, 4, 4);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('KA01GH7878', 'Ather',         '450X',           2024, 'ELECTRIC', 'AUTOMATIC',  5000, 5, 4);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TS09AB9090', 'Kia',           'Seltos',         2022, 'DIESEL',   'MANUAL',    26000, 3, 5);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TS09CD1313', 'Maruti',        'Dzire',          2019, 'CNG',      'MANUAL',    45000, 2, 5);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, category_id, branch_id) VALUES ('TS09EF2424', 'Bajaj',         'Pulsar NS200',   2021, 'PETROL',   'MANUAL',    19000, 6, 5);
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, status, category_id, branch_id) VALUES ('TS09GH3535', 'Hyundai', 'Creta', 2014, 'PETROL', 'MANUAL', 98000, 'RETIRED', 3, 5);

-- ---------------- EMPLOYEE (ids 501..514) ----------------
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Ravi Kumar',      'MANAGER',  '9840011001', 'ravi.k@driveease.in',      65000, DATE '2021-06-01', 1);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Priya Sharma',    'AGENT',    '9840011002', 'priya.s@driveease.in',     32000, DATE '2022-03-15', 1);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Murugan S',       'MECHANIC', '9840011003', 'murugan.s@driveease.in',   28000, DATE '2021-09-10', 1);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Lakshmi Narayan', 'MANAGER',  '9840011004', 'lakshmi.n@driveease.in',   68000, DATE '2020-11-01', 2);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Karthik Raja',    'AGENT',    '9840011005', 'karthik.r@driveease.in',   33000, DATE '2023-01-05', 2);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Senthil Vel',     'MECHANIC', '9840011006', 'senthil.v@driveease.in',   29000, DATE '2022-07-20', 2);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Divya Menon',     'CASHIER',  '9840011007', 'divya.m@driveease.in',     27000, DATE '2023-04-12', 2);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Arun Prakash',    'AGENT',    '9840011008', 'arun.p@driveease.in',      34000, DATE '2022-02-01', 3);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Ganesh Babu',     'MECHANIC', '9840011009', 'ganesh.b@driveease.in',    30000, DATE '2021-12-01', 3);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Sneha Rao',       'MANAGER',  '9840011010', 'sneha.r@driveease.in',     70000, DATE '2021-03-01', 4);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Vikram Gowda',    'AGENT',    '9840011011', 'vikram.g@driveease.in',    35000, DATE '2023-06-01', 4);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Manjunath H',     'MECHANIC', '9840011012', 'manjunath.h@driveease.in', 29500, DATE '2022-10-10', 4);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Sai Teja',        'AGENT',    '9840011013', 'sai.t@driveease.in',       33500, DATE '2023-08-21', 5);
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES ('Ramesh Reddy',    'MECHANIC', '9840011014', 'ramesh.r@driveease.in',    29000, DATE '2022-05-05', 5);

-- ---------------- CUSTOMER (ids 1001..1012) ----------------
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Aditya Verma',    '9876500001', 'aditya.v@gmail.com',    'TN2320190001234', DATE '2035-04-10', DATE '1996-04-10', 'Katpadi, Vellore',          SYSDATE - 200);
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Meera Iyer',      '9876500002', 'meera.iyer@gmail.com',  'TN0920180005678', DATE '2034-08-22', DATE '1994-08-22', 'Adyar, Chennai',            SYSDATE - 180);
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Rahul Nair',      '9876500003', 'rahul.nair@yahoo.com',  'KL0720150004321', DATE '2031-01-15', DATE '1990-01-15', 'Velachery, Chennai',        SYSDATE - 170);
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Fathima Begum',   '9876500004', 'fathima.b@gmail.com',   'TN2220170008765', DATE '2033-11-30', DATE '1992-11-30', 'Tambaram, Chennai',         SYSDATE - 150);
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Sandeep Reddy',   '9876500005', 'sandeep.r@outlook.com', 'TS0920160003434', DATE '2032-06-05', DATE '1988-06-05', 'Gachibowli, Hyderabad',     SYSDATE - 140);
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Kavya Hegde',     '9876500006', 'kavya.h@gmail.com',     'KA0120190007878', DATE '2036-02-18', DATE '1997-02-18', 'HSR Layout, Bengaluru',     SYSDATE - 120);
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Mohammed Irfan',  '9876500007', 'irfan.m@gmail.com',     'TN2320200002323', DATE '2037-09-09', DATE '1999-09-09', 'Gandhi Nagar, Vellore',     SYSDATE - 100);
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Ananya Krishnan', '9876500008', 'ananya.k@gmail.com',    'KA0520180006565', DATE '2034-03-03', DATE '1995-03-03', 'Indiranagar, Bengaluru',    SYSDATE - 90);
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Vignesh Subramani','9876500009','vignesh.s@gmail.com',   'TN0920210009090', DATE '2038-12-12', DATE '2000-12-12', 'Anna Nagar, Chennai',       SYSDATE - 60);
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Pooja Agarwal',   '9876500010', 'pooja.a@gmail.com',     'TS0720170001212', DATE '2033-07-07', DATE '1993-07-07', 'Kondapur, Hyderabad',       SYSDATE - 45);
-- 1011: only 19 years old -> may register but cannot rent (BR-01 test)
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Arjun Das',       '9876500011', 'arjun.das@gmail.com',   'TN2320250000011', ADD_MONTHS(TRUNC(SYSDATE), 230), ADD_MONTHS(TRUNC(SYSDATE), -12*19 - 3), 'Katpadi, Vellore', SYSDATE - 20);
-- 1012: licence expires in 5 days -> cannot take a longer rental (BR-01 test)
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES ('Suresh Pillai',   '9876500012', 'suresh.p@gmail.com',    'TN0920060004040', TRUNC(SYSDATE) + 5, DATE '1980-05-20', 'Mylapore, Chennai',      SYSDATE - 10);

-- ---------------- MAINTENANCE history (inserted as DONE) ----------------
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (101, SYSDATE - 60,  'GENERAL',  'Periodic service, oil change',             3200, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (102, SYSDATE - 75,  'GENERAL',  'Periodic service',                         2900, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (103, SYSDATE - 40,  'GENERAL',  'Periodic service, brake pads',             5400, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (104, SYSDATE - 30,  'GENERAL',  'First free service',                          0, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (105, SYSDATE - 240, 'GENERAL',  'Periodic service',                          900, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (106, SYSDATE - 20,  'TYRE',     'Replaced 2 front tyres',                  11800, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (106, SYSDATE - 90,  'GENERAL',  'Periodic service',                         4800, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (107, SYSDATE - 100, 'GENERAL',  'Periodic service',                         3600, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (108, SYSDATE - 50,  'GENERAL',  'Battery health check, software update',    1500, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (109, SYSDATE - 70,  'GENERAL',  'Chain and clutch adjustment',               1200, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (110, SYSDATE - 35,  'INSURANCE','Annual insurance renewal',                 38000, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (110, SYSDATE - 80,  'GENERAL',  'Periodic service',                        14500, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (111, SYSDATE - 120, 'GENERAL',  'Periodic service',                         3100, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (112, SYSDATE - 150, 'GENERAL',  'Periodic service',                         6200, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (113, SYSDATE - 210, 'GENERAL',  'Periodic service, CNG kit check',          2700, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (114, SYSDATE - 25,  'GENERAL',  'First free service',                          0, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (115, SYSDATE - 55,  'GENERAL',  'Periodic service',                        12500, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (116, SYSDATE - 65,  'GENERAL',  'Firmware update',                            600, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (117, SYSDATE - 45,  'ACCIDENT', 'Rear bumper repaint after minor scrape',   8500, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (117, SYSDATE - 110, 'GENERAL',  'Periodic service',                         4100, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (118, SYSDATE - 130, 'GENERAL',  'Periodic service',                         3300, 'DONE');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES (119, SYSDATE - 260, 'GENERAL',  'Periodic service',                         1100, 'DONE');

-- ---------------- BOOKINGS + PAYMENTS ----------------
-- A small anonymous block with local procedures keeps the history readable.
DECLARE
  v_today DATE := TRUNC(SYSDATE);
  v_id    booking.booking_id%TYPE;
  v_pid   payment.payment_id%TYPE;

  -- completed rental in the past, with advance + final (+ late fee) payments
  PROCEDURE completed (p_cust NUMBER, p_veh NUMBER, p_emp NUMBER, p_from NUMBER, p_to NUMBER,
                       p_start_off NUMBER, p_days NUMBER, p_late_hrs NUMBER, p_km NUMBER,
                       p_method VARCHAR2, p_pay_late BOOLEAN DEFAULT TRUE) IS
    v_start DATE := v_today + p_start_off + 10/24;
    v_end   DATE := v_start + p_days;
    v_odo   NUMBER;
    v_rent  NUMBER;
    v_late  NUMBER;
    v_adv   NUMBER;
  BEGIN
    SELECT odometer INTO v_odo FROM vehicle WHERE vehicle_id = p_veh;
    v_odo := GREATEST(0, v_odo - 4000 + p_start_off * -10);
    INSERT INTO booking (customer_id, vehicle_id, emp_id, pickup_branch_id, return_branch_id,
                         booking_date, start_date, end_date, actual_return_date,
                         start_odometer, end_odometer, status)
    VALUES (p_cust, p_veh, p_emp, p_from, p_to, v_start - 3, v_start, v_end,
            v_end + p_late_hrs / 24, v_odo, v_odo + p_km, 'COMPLETED')
    RETURNING booking_id INTO v_id;

    v_rent := fn_rental_amount(v_id);
    v_late := fn_late_fee(v_id);
    v_adv  := ROUND(v_rent * 0.3, -2);
    INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
    VALUES (v_id, v_adv, v_start - 3, p_method, 'ADVANCE');
    INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
    VALUES (v_id, v_rent - v_adv, v_end + p_late_hrs / 24, p_method, 'FINAL');
    IF v_late > 0 AND p_pay_late THEN
      INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
      VALUES (v_id, v_late, v_end + p_late_hrs / 24, p_method, 'LATE_FEE');
    END IF;
  END completed;

  -- future or current booking created through the real package procedure
  FUNCTION booked (p_cust NUMBER, p_veh NUMBER, p_emp NUMBER, p_ret NUMBER,
                   p_start DATE, p_days NUMBER, p_adv NUMBER, p_method VARCHAR2) RETURN NUMBER IS
    v_bid    NUMBER;
    v_branch NUMBER;
  BEGIN
    SELECT branch_id INTO v_branch FROM vehicle WHERE vehicle_id = p_veh;
    INSERT INTO booking (customer_id, vehicle_id, emp_id, pickup_branch_id, return_branch_id,
                         booking_date, start_date, end_date, status)
    VALUES (p_cust, p_veh, p_emp, v_branch, p_ret, LEAST(SYSDATE, p_start - 2), p_start,
            p_start + p_days, 'BOOKED')
    RETURNING booking_id INTO v_bid;
    IF p_adv > 0 THEN
      INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
      VALUES (v_bid, p_adv, LEAST(SYSDATE, p_start - 2), p_method, 'ADVANCE');
    END IF;
    RETURN v_bid;
  END booked;
BEGIN
  --        cust  veh  emp from to  start  days late km   method
  completed(1001, 101, 502, 1, 1, -150,  3,  0,  420, 'UPI');
  completed(1002, 106, 505, 2, 2, -142,  5,  0,  980, 'CARD');
  completed(1003, 110, 508, 3, 3, -135,  2,  3,  260, 'CARD');
  completed(1005, 117, 513, 5, 5, -128,  4,  0,  760, 'UPI');
  completed(1006, 114, 511, 4, 4, -118,  2,  0,  310, 'NETBANKING');
  completed(1001, 103, 502, 1, 1, -110,  2,  0,  150, 'UPI');
  completed(1004, 107, 505, 2, 2, -101,  3,  5,  540, 'CASH');
  completed(1007, 105, 502, 1, 1,  -95,  6,  0,  280, 'UPI');
  completed(1008, 115, 510, 4, 4,  -88,  2,  0,  220, 'CARD');
  completed(1009, 109, 505, 2, 2,  -80,  4,  2,  690, 'UPI');
  completed(1010, 118, 513, 5, 5,  -74,  3,  0,  450, 'CASH');
  completed(1002, 111, 508, 3, 3,  -66,  2,  0,  190, 'UPI');
  completed(1003, 112, 508, 3, 3,  -58,  5,  0, 1250, 'CARD');
  completed(1005, 119, 513, 5, 5,  -50,  7,  0,  830, 'UPI');
  completed(1001, 104, 501, 1, 1,  -42,  3,  4,  610, 'CARD');
  completed(1006, 116, 511, 4, 4,  -35,  5,  0,  240, 'UPI');
  completed(1004, 108, 505, 2, 2,  -27,  2,  0,  280, 'UPI');
  completed(1007, 102, 502, 1, 1,  -21,  3,  0,  330, 'CASH');
  completed(1008, 113, 511, 4, 4,  -16,  4,  0,  510, 'NETBANKING');
  completed(1009, 106, 504, 2, 2,  -12,  3,  0,  640, 'CARD');
  completed(1010, 117, 513, 5, 5,   -8,  2,  6,  300, 'UPI', FALSE);  -- late fee still unpaid
  completed(1002, 101, 502, 1, 1,   -6,  2,  0,  180, 'UPI');

  -- cancelled bookings (advance + refund)
  v_id := booked(1003, 103, 502, 1, v_today - 70 + 9/24, 2, 1300, 'UPI');
  UPDATE booking SET status = 'CANCELLED' WHERE booking_id = v_id;
  INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
  VALUES (v_id, 1300, v_today - 71, 'UPI', 'REFUND');                      -- >= 24 h before: full refund

  v_id := booked(1009, 111, 508, 3, v_today - 30 + 9/24, 3, 1400, 'CARD');
  UPDATE booking SET status = 'CANCELLED' WHERE booking_id = v_id;
  INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
  VALUES (v_id, 700, v_today - 30 + 4/24, 'CARD', 'REFUND');               -- late cancel: 50 %

  -- ongoing rentals (picked up, not yet returned)
  v_id := booked(1001, 104, 502, 1, v_today - 2 + 10/24, 4, 4000, 'UPI');
  UPDATE booking SET status = 'ONGOING', start_odometer = 15400 WHERE booking_id = v_id;
  UPDATE vehicle SET status = 'RENTED' WHERE vehicle_id = 104;

  v_id := booked(1004, 107, 505, 3, v_today - 1 + 9/24, 2, 1500, 'CARD');  -- one-way T Nagar -> Airport
  UPDATE booking SET status = 'ONGOING', start_odometer = 22000 WHERE booking_id = v_id;
  UPDATE vehicle SET status = 'RENTED' WHERE vehicle_id = 107;

  v_id := booked(1006, 115, 511, 4, v_today - 3 + 9/24, 2, 4000, 'CARD');  -- overdue: end date already passed
  UPDATE booking SET status = 'ONGOING', start_odometer = 8000 WHERE booking_id = v_id;
  UPDATE vehicle SET status = 'RENTED' WHERE vehicle_id = 115;

  -- future bookings
  v_id := booked(1002, 101, 502, 1, v_today + 2 + 9/24,  3, 1500, 'UPI');
  v_id := booked(1003, 110, 508, 3, v_today + 5 + 10/24, 2, 4000, 'CARD');
  v_id := booked(1005, 117, 513, 5, v_today + 1 + 8/24,  3, 3000, 'UPI');
  v_id := booked(1008, 114, 511, 4, v_today + 10 + 9/24, 2,    0, NULL);
END;
/

-- ---------------- open maintenance jobs (trigger sets vehicle to MAINTENANCE) ----------------
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status)
VALUES (112, SYSDATE - 1, 'REPAIR', 'AC compressor not cooling', 0, 'IN_PROGRESS');
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status)
VALUES (118, SYSDATE + 1, 'TYRE', 'Wheel alignment and rotation', 0, 'SCHEDULED');

COMMIT;

PROMPT Seed data loaded.
SELECT 'BRANCH' AS table_name, COUNT(*) AS rows_loaded FROM branch UNION ALL
SELECT 'VEHICLE_CATEGORY', COUNT(*) FROM vehicle_category UNION ALL
SELECT 'VEHICLE',          COUNT(*) FROM vehicle          UNION ALL
SELECT 'CUSTOMER',         COUNT(*) FROM customer         UNION ALL
SELECT 'EMPLOYEE',         COUNT(*) FROM employee         UNION ALL
SELECT 'BOOKING',          COUNT(*) FROM booking          UNION ALL
SELECT 'PAYMENT',          COUNT(*) FROM payment          UNION ALL
SELECT 'MAINTENANCE',      COUNT(*) FROM maintenance;
