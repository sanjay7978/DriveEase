-- =====================================================================
-- DriveEase (MySQL 8) - 06_seed_data.sql : sample data
-- Booking dates are relative to NOW(), so the data always contains
-- past (completed), current (ongoing) and future (booked) rentals.
-- =====================================================================
USE driveease;

-- ---------------- BRANCH (ids 1..5) ----------------
INSERT INTO branch (branch_name, city, address, phone, email) VALUES
  ('DriveEase Katpadi',        'Vellore',   '12 Gandhi Road, Katpadi, Vellore 632007',             '4162243001', 'katpadi@driveease.in'),
  ('DriveEase T Nagar',        'Chennai',   '45 Usman Road, T Nagar, Chennai 600017',              '4424340002', 'tnagar@driveease.in'),
  ('DriveEase Chennai Airport','Chennai',   'GST Road, Meenambakkam, Chennai 600027',              '4422560003', 'maa-airport@driveease.in'),
  ('DriveEase Koramangala',    'Bengaluru', '80 Feet Road, Koramangala 4th Block, Bengaluru 560034','8041120004', 'koramangala@driveease.in'),
  ('DriveEase Hitech City',    'Hyderabad', 'Plot 7, Madhapur Main Road, Hyderabad 500081',        '4023110005', 'hitech@driveease.in');

-- ---------------- VEHICLE_CATEGORY (ids 1..6) ----------------
INSERT INTO vehicle_category (category_name, daily_rate, late_fee_per_hr, seating_capacity, security_deposit) VALUES
  ('Hatchback', 1500, 100, 5,  3000),
  ('Sedan',     2200, 150, 5,  5000),
  ('SUV',       3200, 200, 7,  7000),
  ('Luxury',    6500, 400, 5, 15000),
  ('Scooter',    500,  40, 2,  1000),
  ('Motorbike',  800,  60, 2,  1500);

-- ---------------- VEHICLE (ids 101..120) ----------------
INSERT INTO vehicle (reg_number, brand, model, mfg_year, fuel_type, transmission, odometer, status, category_id, branch_id) VALUES
  ('TN23AB1234', 'Maruti',        'Swift',         2022, 'PETROL',   'MANUAL',    24500, 'AVAILABLE', 1, 1),
  ('TN23CD5678', 'Hyundai',       'i20',           2023, 'PETROL',   'AUTOMATIC', 18200, 'AVAILABLE', 1, 1),
  ('TN23EF4321', 'Honda',         'City',          2021, 'PETROL',   'AUTOMATIC', 31000, 'AVAILABLE', 2, 1),
  ('TN23GH8765', 'Mahindra',      'XUV700',        2023, 'DIESEL',   'AUTOMATIC', 15400, 'AVAILABLE', 3, 1),
  ('TN23JK1111', 'Honda',         'Activa 6G',     2022, 'PETROL',   'AUTOMATIC',  8200, 'AVAILABLE', 5, 1),
  ('TN09AB2222', 'Toyota',        'Innova Crysta', 2020, 'DIESEL',   'MANUAL',    52000, 'AVAILABLE', 3, 2),
  ('TN09CD3333', 'Hyundai',       'Verna',         2022, 'PETROL',   'AUTOMATIC', 22000, 'AVAILABLE', 2, 2),
  ('TN09EF4444', 'Tata',          'Nexon EV',      2024, 'ELECTRIC', 'AUTOMATIC',  9800, 'AVAILABLE', 3, 2),
  ('TN09GH5555', 'Royal Enfield', 'Classic 350',   2021, 'PETROL',   'MANUAL',    14000, 'AVAILABLE', 6, 2),
  ('TN22AB6666', 'Mercedes-Benz', 'C-Class',       2023, 'DIESEL',   'AUTOMATIC', 12000, 'AVAILABLE', 4, 3),
  ('TN22CD7777', 'Maruti',        'Baleno',        2021, 'PETROL',   'MANUAL',    27000, 'AVAILABLE', 1, 3),
  ('TN22EF8888', 'Toyota',        'Fortuner',      2020, 'DIESEL',   'AUTOMATIC', 41000, 'AVAILABLE', 3, 3),
  ('KA01AB1212', 'Tata',          'Tiago',         2020, 'CNG',      'MANUAL',    33000, 'AVAILABLE', 1, 4),
  ('KA01CD3434', 'Skoda',         'Slavia',        2024, 'PETROL',   'AUTOMATIC', 11000, 'AVAILABLE', 2, 4),
  ('KA01EF5656', 'BMW',           '3 Series',      2023, 'PETROL',   'AUTOMATIC',  8000, 'AVAILABLE', 4, 4),
  ('KA01GH7878', 'Ather',         '450X',          2024, 'ELECTRIC', 'AUTOMATIC',  5000, 'AVAILABLE', 5, 4),
  ('TS09AB9090', 'Kia',           'Seltos',        2022, 'DIESEL',   'MANUAL',    26000, 'AVAILABLE', 3, 5),
  ('TS09CD1313', 'Maruti',        'Dzire',         2019, 'CNG',      'MANUAL',    45000, 'AVAILABLE', 2, 5),
  ('TS09EF2424', 'Bajaj',         'Pulsar NS200',  2021, 'PETROL',   'MANUAL',    19000, 'AVAILABLE', 6, 5),
  ('TS09GH3535', 'Hyundai',       'Creta',         2014, 'PETROL',   'MANUAL',    98000, 'RETIRED',   3, 5);

-- ---------------- EMPLOYEE (ids 501..514) ----------------
INSERT INTO employee (name, role, phone, email, salary, hire_date, branch_id) VALUES
  ('Ravi Kumar',      'MANAGER',  '9840011001', 'ravi.k@driveease.in',      65000, '2021-06-01', 1),
  ('Priya Sharma',    'AGENT',    '9840011002', 'priya.s@driveease.in',     32000, '2022-03-15', 1),
  ('Murugan S',       'MECHANIC', '9840011003', 'murugan.s@driveease.in',   28000, '2021-09-10', 1),
  ('Lakshmi Narayan', 'MANAGER',  '9840011004', 'lakshmi.n@driveease.in',   68000, '2020-11-01', 2),
  ('Karthik Raja',    'AGENT',    '9840011005', 'karthik.r@driveease.in',   33000, '2023-01-05', 2),
  ('Senthil Vel',     'MECHANIC', '9840011006', 'senthil.v@driveease.in',   29000, '2022-07-20', 2),
  ('Divya Menon',     'CASHIER',  '9840011007', 'divya.m@driveease.in',     27000, '2023-04-12', 2),
  ('Arun Prakash',    'AGENT',    '9840011008', 'arun.p@driveease.in',      34000, '2022-02-01', 3),
  ('Ganesh Babu',     'MECHANIC', '9840011009', 'ganesh.b@driveease.in',    30000, '2021-12-01', 3),
  ('Sneha Rao',       'MANAGER',  '9840011010', 'sneha.r@driveease.in',     70000, '2021-03-01', 4),
  ('Vikram Gowda',    'AGENT',    '9840011011', 'vikram.g@driveease.in',    35000, '2023-06-01', 4),
  ('Manjunath H',     'MECHANIC', '9840011012', 'manjunath.h@driveease.in', 29500, '2022-10-10', 4),
  ('Sai Teja',        'AGENT',    '9840011013', 'sai.t@driveease.in',       33500, '2023-08-21', 5),
  ('Ramesh Reddy',    'MECHANIC', '9840011014', 'ramesh.r@driveease.in',    29000, '2022-05-05', 5);

-- ---------------- CUSTOMER (ids 1001..1012) ----------------
INSERT INTO customer (name, phone, email, license_no, license_expiry, dob, address, registered_on) VALUES
  ('Aditya Verma',     '9876500001', 'aditya.v@gmail.com',    'TN2320190001234', '2035-04-10', '1996-04-10', 'Katpadi, Vellore',       CURDATE() - INTERVAL 200 DAY),
  ('Meera Iyer',       '9876500002', 'meera.iyer@gmail.com',  'TN0920180005678', '2034-08-22', '1994-08-22', 'Adyar, Chennai',         CURDATE() - INTERVAL 180 DAY),
  ('Rahul Nair',       '9876500003', 'rahul.nair@yahoo.com',  'KL0720150004321', '2031-01-15', '1990-01-15', 'Velachery, Chennai',     CURDATE() - INTERVAL 170 DAY),
  ('Fathima Begum',    '9876500004', 'fathima.b@gmail.com',   'TN2220170008765', '2033-11-30', '1992-11-30', 'Tambaram, Chennai',      CURDATE() - INTERVAL 150 DAY),
  ('Sandeep Reddy',    '9876500005', 'sandeep.r@outlook.com', 'TS0920160003434', '2032-06-05', '1988-06-05', 'Gachibowli, Hyderabad',  CURDATE() - INTERVAL 140 DAY),
  ('Kavya Hegde',      '9876500006', 'kavya.h@gmail.com',     'KA0120190007878', '2036-02-18', '1997-02-18', 'HSR Layout, Bengaluru',  CURDATE() - INTERVAL 120 DAY),
  ('Mohammed Irfan',   '9876500007', 'irfan.m@gmail.com',     'TN2320200002323', '2037-09-09', '1999-09-09', 'Gandhi Nagar, Vellore',  CURDATE() - INTERVAL 100 DAY),
  ('Ananya Krishnan',  '9876500008', 'ananya.k@gmail.com',    'KA0520180006565', '2034-03-03', '1995-03-03', 'Indiranagar, Bengaluru', CURDATE() - INTERVAL 90 DAY),
  ('Vignesh Subramani','9876500009', 'vignesh.s@gmail.com',   'TN0920210009090', '2038-12-12', '2000-12-12', 'Anna Nagar, Chennai',    CURDATE() - INTERVAL 60 DAY),
  ('Pooja Agarwal',    '9876500010', 'pooja.a@gmail.com',     'TS0720170001212', '2033-07-07', '1993-07-07', 'Kondapur, Hyderabad',    CURDATE() - INTERVAL 45 DAY),
  -- 1011: only 19 years old -> may register but cannot rent (BR-01 test)
  ('Arjun Das',        '9876500011', 'arjun.das@gmail.com',   'TN2320250000011', CURDATE() + INTERVAL 230 MONTH,
                                                                                 CURDATE() - INTERVAL 231 MONTH, 'Katpadi, Vellore',     CURDATE() - INTERVAL 20 DAY),
  -- 1012: licence expires in 5 days -> cannot take a longer rental (BR-01 test)
  ('Suresh Pillai',    '9876500012', 'suresh.p@gmail.com',    'TN0920060004040', CURDATE() + INTERVAL 5 DAY, '1980-05-20', 'Mylapore, Chennai',   CURDATE() - INTERVAL 10 DAY);

-- ---------------- MAINTENANCE history (inserted as DONE) ----------------
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES
  (101, NOW() - INTERVAL 60 DAY,  'GENERAL',   'Periodic service, oil change',           3200, 'DONE'),
  (102, NOW() - INTERVAL 75 DAY,  'GENERAL',   'Periodic service',                       2900, 'DONE'),
  (103, NOW() - INTERVAL 40 DAY,  'GENERAL',   'Periodic service, brake pads',           5400, 'DONE'),
  (104, NOW() - INTERVAL 30 DAY,  'GENERAL',   'First free service',                        0, 'DONE'),
  (105, NOW() - INTERVAL 240 DAY, 'GENERAL',   'Periodic service',                        900, 'DONE'),
  (106, NOW() - INTERVAL 20 DAY,  'TYRE',      'Replaced 2 front tyres',                11800, 'DONE'),
  (106, NOW() - INTERVAL 90 DAY,  'GENERAL',   'Periodic service',                       4800, 'DONE'),
  (107, NOW() - INTERVAL 100 DAY, 'GENERAL',   'Periodic service',                       3600, 'DONE'),
  (108, NOW() - INTERVAL 50 DAY,  'GENERAL',   'Battery health check, software update',  1500, 'DONE'),
  (109, NOW() - INTERVAL 70 DAY,  'GENERAL',   'Chain and clutch adjustment',            1200, 'DONE'),
  (110, NOW() - INTERVAL 35 DAY,  'INSURANCE', 'Annual insurance renewal',              38000, 'DONE'),
  (110, NOW() - INTERVAL 80 DAY,  'GENERAL',   'Periodic service',                      14500, 'DONE'),
  (111, NOW() - INTERVAL 120 DAY, 'GENERAL',   'Periodic service',                       3100, 'DONE'),
  (112, NOW() - INTERVAL 150 DAY, 'GENERAL',   'Periodic service',                       6200, 'DONE'),
  (113, NOW() - INTERVAL 210 DAY, 'GENERAL',   'Periodic service, CNG kit check',        2700, 'DONE'),
  (114, NOW() - INTERVAL 25 DAY,  'GENERAL',   'First free service',                        0, 'DONE'),
  (115, NOW() - INTERVAL 55 DAY,  'GENERAL',   'Periodic service',                      12500, 'DONE'),
  (116, NOW() - INTERVAL 65 DAY,  'GENERAL',   'Firmware update',                         600, 'DONE'),
  (117, NOW() - INTERVAL 45 DAY,  'ACCIDENT',  'Rear bumper repaint after minor scrape',  8500, 'DONE'),
  (117, NOW() - INTERVAL 110 DAY, 'GENERAL',   'Periodic service',                       4100, 'DONE'),
  (118, NOW() - INTERVAL 130 DAY, 'GENERAL',   'Periodic service',                       3300, 'DONE'),
  (119, NOW() - INTERVAL 260 DAY, 'GENERAL',   'Periodic service',                       1100, 'DONE');

-- ---------------- BOOKINGS + PAYMENTS ----------------
-- Two temporary helper procedures keep the history readable; they are
-- dropped again at the end of this script.
DROP PROCEDURE IF EXISTS seed_completed;
DROP PROCEDURE IF EXISTS seed_booked;

DELIMITER $$

-- completed rental in the past, with advance + final (+ late fee) payments
CREATE PROCEDURE seed_completed (
  p_cust INT, p_veh INT, p_emp INT, p_from INT, p_to INT,
  p_start_off INT, p_days INT, p_late_hrs INT, p_km INT, p_method VARCHAR(12), p_pay_late BOOLEAN)
BEGIN
  DECLARE v_start DATETIME DEFAULT CURDATE() + INTERVAL p_start_off DAY + INTERVAL 10 HOUR;
  DECLARE v_end   DATETIME;
  DECLARE v_ret   DATETIME;
  DECLARE v_odo   INT;
  DECLARE v_id    INT;
  DECLARE v_rent  DECIMAL(10,2);
  DECLARE v_late  DECIMAL(10,2);
  DECLARE v_adv   DECIMAL(10,2);

  SET v_end = v_start + INTERVAL p_days DAY;
  SET v_ret = v_end + INTERVAL p_late_hrs HOUR;
  SELECT GREATEST(0, odometer - 4000 - p_start_off * 10) INTO v_odo FROM vehicle WHERE vehicle_id = p_veh;

  INSERT INTO booking (customer_id, vehicle_id, emp_id, pickup_branch_id, return_branch_id, booking_date,
                       start_date, end_date, actual_return_date, start_odometer, end_odometer, status)
  VALUES (p_cust, p_veh, p_emp, p_from, p_to, v_start - INTERVAL 3 DAY,
          v_start, v_end, v_ret, v_odo, v_odo + p_km, 'COMPLETED');
  SET v_id = LAST_INSERT_ID();

  SET v_rent = fn_rental_amount(v_id);
  SET v_late = fn_late_fee(v_id, NULL);
  SET v_adv  = ROUND(v_rent * 0.3, -2);
  INSERT INTO payment (booking_id, amount, payment_date, method, payment_type) VALUES
    (v_id, v_adv,          v_start - INTERVAL 3 DAY, p_method, 'ADVANCE'),
    (v_id, v_rent - v_adv, v_ret,                    p_method, 'FINAL');
  IF v_late > 0 AND p_pay_late THEN
    INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
    VALUES (v_id, v_late, v_ret, p_method, 'LATE_FEE');
  END IF;
END$$

-- current / future booking (status BOOKED) with an optional advance
CREATE PROCEDURE seed_booked (
  p_cust INT, p_veh INT, p_emp INT, p_ret INT, p_start DATETIME, p_days INT,
  p_adv DECIMAL(9,2), p_method VARCHAR(12), OUT p_id INT)
BEGIN
  DECLARE v_branch INT;
  SELECT branch_id INTO v_branch FROM vehicle WHERE vehicle_id = p_veh;
  INSERT INTO booking (customer_id, vehicle_id, emp_id, pickup_branch_id, return_branch_id,
                       booking_date, start_date, end_date, status)
  VALUES (p_cust, p_veh, p_emp, v_branch, p_ret, LEAST(NOW(), p_start - INTERVAL 2 DAY),
          p_start, p_start + INTERVAL p_days DAY, 'BOOKED');
  SET p_id = LAST_INSERT_ID();
  IF p_adv > 0 THEN
    INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
    VALUES (p_id, p_adv, LEAST(NOW(), p_start - INTERVAL 2 DAY), p_method, 'ADVANCE');
  END IF;
END$$

DELIMITER ;

--                   cust  veh  emp from to  start days late  km   method        pay late fee?
CALL seed_completed(1001, 101, 502, 1, 1, -150,  3,  0,  420, 'UPI',        TRUE);
CALL seed_completed(1002, 106, 505, 2, 2, -142,  5,  0,  980, 'CARD',       TRUE);
CALL seed_completed(1003, 110, 508, 3, 3, -135,  2,  3,  260, 'CARD',       TRUE);
CALL seed_completed(1005, 117, 513, 5, 5, -128,  4,  0,  760, 'UPI',        TRUE);
CALL seed_completed(1006, 114, 511, 4, 4, -118,  2,  0,  310, 'NETBANKING', TRUE);
CALL seed_completed(1001, 103, 502, 1, 1, -110,  2,  0,  150, 'UPI',        TRUE);
CALL seed_completed(1004, 107, 505, 2, 2, -101,  3,  5,  540, 'CASH',       TRUE);
CALL seed_completed(1007, 105, 502, 1, 1,  -95,  6,  0,  280, 'UPI',        TRUE);
CALL seed_completed(1008, 115, 510, 4, 4,  -88,  2,  0,  220, 'CARD',       TRUE);
CALL seed_completed(1009, 109, 505, 2, 2,  -80,  4,  2,  690, 'UPI',        TRUE);
CALL seed_completed(1010, 118, 513, 5, 5,  -74,  3,  0,  450, 'CASH',       TRUE);
CALL seed_completed(1002, 111, 508, 3, 3,  -66,  2,  0,  190, 'UPI',        TRUE);
CALL seed_completed(1003, 112, 508, 3, 3,  -58,  5,  0, 1250, 'CARD',       TRUE);
CALL seed_completed(1005, 119, 513, 5, 5,  -50,  7,  0,  830, 'UPI',        TRUE);
CALL seed_completed(1001, 104, 501, 1, 1,  -42,  3,  4,  610, 'CARD',       TRUE);
CALL seed_completed(1006, 116, 511, 4, 4,  -35,  5,  0,  240, 'UPI',        TRUE);
CALL seed_completed(1004, 108, 505, 2, 2,  -27,  2,  0,  280, 'UPI',        TRUE);
CALL seed_completed(1007, 102, 502, 1, 1,  -21,  3,  0,  330, 'CASH',       TRUE);
CALL seed_completed(1008, 113, 511, 4, 4,  -16,  4,  0,  510, 'NETBANKING', TRUE);
CALL seed_completed(1009, 106, 504, 2, 2,  -12,  3,  0,  640, 'CARD',       TRUE);
CALL seed_completed(1010, 117, 513, 5, 5,   -8,  2,  6,  300, 'UPI',        FALSE);  -- late fee still unpaid
CALL seed_completed(1002, 101, 502, 1, 1,   -6,  2,  0,  180, 'UPI',        TRUE);

-- cancelled bookings (advance, then refund)
CALL seed_booked(1003, 103, 502, 1, CURDATE() - INTERVAL 70 DAY + INTERVAL 9 HOUR, 2, 1300, 'UPI', @b);
UPDATE booking SET status = 'CANCELLED' WHERE booking_id = @b;
INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
VALUES (@b, 1300, CURDATE() - INTERVAL 71 DAY, 'UPI', 'REFUND');                   -- >= 24 h before: full refund

CALL seed_booked(1009, 111, 508, 3, CURDATE() - INTERVAL 30 DAY + INTERVAL 9 HOUR, 3, 1400, 'CARD', @b);
UPDATE booking SET status = 'CANCELLED' WHERE booking_id = @b;
INSERT INTO payment (booking_id, amount, payment_date, method, payment_type)
VALUES (@b, 700, CURDATE() - INTERVAL 30 DAY + INTERVAL 4 HOUR, 'CARD', 'REFUND');  -- late cancel: 50 %

-- ongoing rentals (picked up, not yet returned)
CALL seed_booked(1001, 104, 502, 1, CURDATE() - INTERVAL 2 DAY + INTERVAL 10 HOUR, 4, 4000, 'UPI', @b);
UPDATE booking SET status = 'ONGOING', start_odometer = 15400 WHERE booking_id = @b;
UPDATE vehicle SET status = 'RENTED' WHERE vehicle_id = 104;

CALL seed_booked(1004, 107, 505, 3, CURDATE() - INTERVAL 1 DAY + INTERVAL 9 HOUR, 2, 1500, 'CARD', @b);  -- one-way T Nagar -> Airport
UPDATE booking SET status = 'ONGOING', start_odometer = 22000 WHERE booking_id = @b;
UPDATE vehicle SET status = 'RENTED' WHERE vehicle_id = 107;

CALL seed_booked(1006, 115, 511, 4, CURDATE() - INTERVAL 3 DAY + INTERVAL 9 HOUR, 2, 4000, 'CARD', @b);  -- overdue
UPDATE booking SET status = 'ONGOING', start_odometer = 8000 WHERE booking_id = @b;
UPDATE vehicle SET status = 'RENTED' WHERE vehicle_id = 115;

-- future bookings
CALL seed_booked(1002, 101, 502, 1, CURDATE() + INTERVAL 2 DAY  + INTERVAL 9 HOUR,  3, 1500, 'UPI',  @b);
CALL seed_booked(1003, 110, 508, 3, CURDATE() + INTERVAL 5 DAY  + INTERVAL 10 HOUR, 2, 4000, 'CARD', @b);
CALL seed_booked(1005, 117, 513, 5, CURDATE() + INTERVAL 1 DAY  + INTERVAL 8 HOUR,  3, 3000, 'UPI',  @b);
CALL seed_booked(1008, 114, 511, 4, CURDATE() + INTERVAL 10 DAY + INTERVAL 9 HOUR,  2,    0, NULL,   @b);

DROP PROCEDURE seed_completed;
DROP PROCEDURE seed_booked;

-- ---------------- open maintenance jobs (trigger sets vehicle to MAINTENANCE) ----------------
INSERT INTO maintenance (vehicle_id, service_date, service_type, description, cost, maint_status) VALUES
  (112, NOW() - INTERVAL 1 DAY, 'REPAIR', 'AC compressor not cooling',    0, 'IN_PROGRESS'),
  (118, NOW() + INTERVAL 1 DAY, 'TYRE',   'Wheel alignment and rotation', 0, 'SCHEDULED');

SELECT 'BRANCH' AS table_name, COUNT(*) AS rows_loaded FROM branch UNION ALL
SELECT 'VEHICLE_CATEGORY', COUNT(*) FROM vehicle_category UNION ALL
SELECT 'VEHICLE',          COUNT(*) FROM vehicle          UNION ALL
SELECT 'CUSTOMER',         COUNT(*) FROM customer         UNION ALL
SELECT 'EMPLOYEE',         COUNT(*) FROM employee         UNION ALL
SELECT 'BOOKING',          COUNT(*) FROM booking          UNION ALL
SELECT 'PAYMENT',          COUNT(*) FROM payment          UNION ALL
SELECT 'MAINTENANCE',      COUNT(*) FROM maintenance;
