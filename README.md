# DriveEase – Vehicle Rental Management System

**Course:** BCSE302L Database Systems – Review II (implementation)
**Team:** R. Sanjay, Moningi Nidhi
**Database:** MySQL 8 (installed with Homebrew), database `driveease`
**Editor:** Visual Studio Code
**Front-end:** Python Flask web app connected to MySQL with PyMySQL

---

## 1. Folder layout

```
DriveEase/
├── sql/
│   ├── 00_create_database.sql  run once as root: database + user driveease
│   ├── 01_tables.sql           8 tables from Review I + BOOKING_AUDIT, all keys and CHECK constraints
│   ├── 02_functions.sql        7 stored functions
│   ├── 03_procedures.sql       6 stand-alone procedures
│   ├── 04_modules.sql          2 views + 16 procedures in 3 modules (rental_*, fleet_*, report_*)
│   ├── 05_triggers.sql         12 triggers
│   ├── 06_seed_data.sql        5 branches, 6 categories, 20 vehicles, 14 staff, 12 customers, 31 bookings…
│   ├── 07_test_cases.sql       run_all_tests(): 28 automated test cases
│   └── 08_demo_queries.sql     queries to run in VS Code for output screenshots
├── setup_database.py           builds / resets the whole database from sql/
├── app/                        Flask website (app.py, db.py, templates/, static/)
├── screenshots/                22 output screenshots + test_output.txt
└── .vscode/                    Run configurations + recommended extensions
```

## 2. Open the project in VS Code

1. **File → Open Folder… → `Desktop/DriveEase`**.
2. When VS Code asks *"Do you want to install the recommended extensions?"*, click **Install**.
   This installs **Database Client** (`cweijan.vscode-mysql-client2`), which lets you browse MySQL and run SQL, and the **Python** extension.
3. MySQL must be running. It starts automatically at login; if not, run:
   ```bash
   brew services start mysql
   ```

### Connect to the database in VS Code
Click the **Database** icon in the left bar, then **+ (Create Connection)**:

| Field | Value |
|---|---|
| Server type | MySQL |
| Host | `127.0.0.1` |
| Port | `3306` |
| Username | `driveease` |
| Password | `driveease` |
| Database | `driveease` |

Expand **driveease** to see **Tables, Views, Procedures, Functions and Triggers**, and click any one to see its code.

### Run SQL in VS Code
Open `sql/08_demo_queries.sql`. Choose the `driveease` connection at the top of the editor, put the cursor on a statement, and press **Ctrl+Enter** (or click ▶ Run). Results appear in a grid, ready for screenshots.
The first one is `CALL run_all_tests();`, which shows all 28 test cases with PASS/FAIL.

## 3. Run menu (Run and Debug, ⇧⌘D)

`.vscode/launch.json` has three ready-made entries. Pick one and press ▶:

| Entry | What it does |
|---|---|
| **1. Build database (reset sample data)** | runs every file in `sql/` in order, giving fresh sample data |
| **2. Build database + run 28 test cases** | same as 1, then prints the test results in the terminal |
| **3. Start website** | starts the site at **http://127.0.0.1:5050** |

The same from the VS Code terminal:
```bash
.venv/bin/python setup_database.py --tests
```
```bash
.venv/bin/python app/app.py
```

## 4. Website pages

| Page | What it does | Database object called |
|---|---|---|
| Dashboard | fleet status, revenue, dues, overdue returns, audit log | `fn_balance_due`, `fn_late_fee`, `booking_audit` |
| Find a ride | availability by city / category / dates (FR-03) | `rental_search_available` |
| New booking | create booking + advance (FR-04) | `rental_create_booking` + triggers |
| Booking detail | pickup, return, cancel, payments (FR-05…FR-08) | `rental_record_pickup`, `rental_record_return`, `rental_cancel_booking`, `rental_add_payment` |
| Customers | register + history (FR-01, FR-12) | `sp_register_customer`, `rental_customer_history` |
| Fleet | add / retire (FR-02) | `sp_add_vehicle`, `sp_retire_vehicle` |
| Garage | schedule / close / auto-schedule (FR-09) | `fleet_*` procedures, maintenance triggers |
| Reports | revenue, branch summary, top customers, dues, utilisation (FR-11) | `report_*` procedures |
| Branches | branches, employees, category prices (FR-10) | `sp_add_branch`, `sp_add_employee`, `sp_update_category_rate` |
| Tests | runs all 28 tests inside MySQL | `run_all_tests()` |
| Database | lists every object and shows its SQL | `INFORMATION_SCHEMA`, `SHOW CREATE` |

Any error raised by a trigger or procedure (error numbers 200xx) is shown to the user as a red message.

## 5. Stored objects

### Functions (`02_functions.sql`)
| Function | Purpose | Rule |
|---|---|---|
| `fn_customer_age(customer, date)` | derived attribute *age* | BR-01 |
| `fn_rental_days(booking)` | derived attribute *rental_days*, minimum 1 | BR-04 |
| `fn_rental_amount(booking)` | days × category daily rate | BR-04 |
| `fn_late_fee(booking, what-if date)` | started hours late × late_fee_per_hr | BR-05 |
| `fn_total_paid(booking)` | successful payments − refunds | FR-07 |
| `fn_balance_due(booking)` | rent + late fee − paid | FR-11 |
| `fn_is_vehicle_available(vehicle, start, end)` | 'Y'/'N', usable in SQL | BR-02, BR-03 |

### Procedures (`03_procedures.sql`)
`sp_register_customer`, `sp_add_branch`, `sp_add_employee`, `sp_add_vehicle`, `sp_retire_vehicle`, `sp_update_category_rate`. They use IN/OUT parameters, `SIGNAL` for business errors, and handlers for duplicate keys (error 1062).

### Packages → Modules (`04_modules.sql`)
**MySQL has no `CREATE PACKAGE`** (that is an Oracle PL/SQL feature). The package idea, related procedures grouped under one name, is implemented as **modules**: each routine carries its module's prefix and the module lives in one file.

* **`rental_*`**: `rental_search_available`, `rental_create_booking`, `rental_record_pickup`, `rental_record_return` (rent + late fee, one-way transfer BR-07, optional settlement), `rental_cancel_booking` (BR-06 refund rule), `rental_add_payment`, `rental_customer_history`, `rental_print_customer_history` (nested explicit cursors).
* **`fleet_*`**: `fleet_schedule_maintenance`, `fleet_update_maintenance`, `fleet_auto_schedule_service` (explicit cursor).
* **`report_*`**: `report_branch_revenue`, `report_fleet_utilisation`, `report_top_customers`, `report_pending_dues`, `report_branch_summary` (nested explicit cursors).
* **Views** `v_vehicle_catalog`, `v_booking_summary` are shared by the modules and the website.

Multi-step procedures are **atomic**: if anything fails, everything they did is rolled back (`SAVEPOINT` / `ROLLBACK`), as the NFR "Consistency" requires.

### Triggers (`05_triggers.sql`)
| Trigger | Timing | Enforces |
|---|---|---|
| `trg_customer_before_insert` | BEFORE INSERT ON customer | DOB not in future, age ≥ 18, licence not expired |
| `trg_customer_before_update` | BEFORE UPDATE ON customer | valid DOB on update |
| `trg_booking_before_insert` | BEFORE INSERT ON booking | **BR-01** age ≥ 21 and licence valid to end date; **BR-03** no MAINTENANCE/RETIRED vehicle; **BR-02** no double booking |
| `trg_booking_before_update` | BEFORE UPDATE ON booking | status only BOOKED→ONGOING/CANCELLED, ONGOING→COMPLETED; re-checks overlap |
| `trg_booking_after_insert` / `_after_update` / `_after_delete` | AFTER … ON booking | write BOOKING_AUDIT |
| `trg_vehicle_before_update` | BEFORE UPDATE ON vehicle | odometer never decreases (BR-08) |
| `trg_maint_before_insert` | BEFORE INSERT ON maintenance | no maintenance on a RENTED/RETIRED vehicle |
| `trg_maint_after_insert` / `_after_update` | AFTER … ON maintenance | vehicle → MAINTENANCE, back to AVAILABLE when DONE (FR-09) |
| `trg_payment_before_insert` | BEFORE INSERT ON payment | only REFUND on cancelled bookings; REFUND only on cancelled/completed |

BR-08 (`end_odometer >= start_odometer`) and the date rules are also CHECK constraints on BOOKING.

### Cursors used
* **Explicit cursor** (`DECLARE … CURSOR`, `OPEN`, `FETCH`, `CONTINUE HANDLER FOR NOT FOUND`, `CLOSE`): `fleet_auto_schedule_service`, and the pending-dues cursor in test TC27.
* **Nested explicit cursors**: `rental_print_customer_history` (bookings → payments) and `report_branch_summary` (branches → vehicles by status).
* **Result-set procedures** (MySQL's equivalent of Oracle REF CURSORs): `rental_search_available`, `rental_customer_history`, all `report_*`.
* **`ROW_COUNT()`**, the implicit-cursor row count: `sp_retire_vehicle`.

## 6. Test cases: `CALL run_all_tests();` gives 28/28 PASS

The tests create their own test vehicles and **roll back everything at the end**, so they pass on any state of the data and never change it. Full output: `screenshots/test_output.txt`.

| TC | Area | Test | Expected |
|---|---|---|---|
| 01 | Function | `fn_customer_age` | correct age |
| 02 | Function | `fn_is_vehicle_available` | N for maintenance, Y for free |
| 03 | Procedure | register valid customer | created |
| 04 | Procedure | duplicate licence | error 20020 |
| 05 | Procedure | add vehicle | status AVAILABLE |
| 06 | Procedure | retire vehicle with open booking | error 20024 |
| 07 | Module | create booking + advance | rent = 3 × 1500 |
| 08 | Module | search hides booked vehicle | not listed |
| 09 | Module | pickup | ONGOING / RENTED |
| 10 | Module | return 3 h late, one-way | late fee 300, branch moved, balance 0 |
| 11 | Module | cancel ≥ 24 h before | 100% refund |
| 12 | Module | cancel < 24 h before | 50% refund |
| 13 | Module | booking by a mechanic | error 20033 |
| 14 | Trigger | customer aged 19 | error 20001 |
| 15 | Trigger | licence expires during rental | error 20002 |
| 16 | Trigger | double booking | error 20004 |
| 17 | Trigger | vehicle in maintenance | error 20003 |
| 18 | Trigger | odometer goes back | error 20006 |
| 19 | Trigger | COMPLETED → BOOKED | error 20005 |
| 20 | Trigger | payment on cancelled booking | error 20008 |
| 21 | Trigger | audit rows written | 3 rows |
| 22 | Trigger | maintenance open/close | MAINTENANCE → AVAILABLE |
| 23 | Trigger | maintenance on rented vehicle | error 20007 |
| 24 | Module | end odometer < start | error 20051 |
| 25 | Trigger | expired licence at registration | error 20013 |
| 26 | Cursor | auto-schedule service | jobs created |
| 27 | Cursor | pending dues | unpaid rental listed |
| 28 | Cursor | customer history | all bookings returned |

## 7. Screenshots (`screenshots/`)
`01`–`03` dashboard, fleet, availability search · `04`–`09` triggers/procedures rejecting invalid data ·
`10`–`14` booking life-cycle (create, pickup, late one-way return, full and 50% refunds) · `15`–`16` maintenance ·
`17`–`19` history, reports, admin · `20` all 28 tests passing · `21`–`22` database objects and trigger source.
Add your own VS Code screenshots of `sql/08_demo_queries.sql` results next to these.

## 8. Viva notes: Oracle vs MySQL
| Oracle PL/SQL | What this project uses in MySQL |
|---|---|
| `CREATE PACKAGE` | modules with a name prefix (`rental_*`, `fleet_*`, `report_*`) |
| `RAISE_APPLICATION_ERROR(-20001, …)` | `SIGNAL SQLSTATE '45000' SET MYSQL_ERRNO = 20001, MESSAGE_TEXT = …` |
| `SYS_REFCURSOR` | procedure returning a result set |
| `%NOTFOUND` | `DECLARE CONTINUE HANDLER FOR NOT FOUND` |
| `SQL%ROWCOUNT` | `ROW_COUNT()` |
| `DBMS_OUTPUT` | `SELECT` from a temporary table |
| Sequences | `AUTO_INCREMENT` (starting at 101, 1001, 5001 …) |
| `SYSDATE` | `NOW()` |
