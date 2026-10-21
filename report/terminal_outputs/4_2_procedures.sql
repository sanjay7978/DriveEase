-- Figure 4.2  Procedures
-- Run: mysql -u driveease -pdriveease -t -v --force driveease < report/terminal_outputs/4_2_procedures.sql
-- The data is left unchanged, so it can be run any number of times.

START TRANSACTION;
CALL sp_register_customer('Karan Mehta', '9123456780', 'karan.m@gmail.com', 'TN2320220007777', '2036-01-31', '1999-05-14', 'Vellore', @new_id);
SELECT @new_id AS new_customer_id;
SELECT customer_id, name, license_no, fn_customer_age(customer_id, NULL) AS age FROM customer WHERE customer_id = @new_id;
CALL sp_register_customer('Duplicate Licence', '9123456781', NULL, 'TN2320220007777', '2036-01-31', '1999-05-14', NULL, @x);
CALL sp_retire_vehicle(104);
ROLLBACK;
