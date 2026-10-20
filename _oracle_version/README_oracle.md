# DriveEase – Vehicle Rental Management System

**Course:** BCSE302L Database Systems – Review II (implementation)
**Team:** R. Sanjay, Moningi Nidhi
**Database:** Oracle Database 21c XE (Docker container `oracle-xe`), PDB `XEPDB1`, schema `DRIVEEASE`
**Front-end:** Python Flask web app with python-oracledb (thin mode, so no Oracle client install is needed)

---

## 1. Folder layout

```
DriveEase/
├── sql/
│   ├── 00_create_user.sql     run once as SYS: creates user DRIVEEASE
│   ├── run_all.sql            builds everything below in order (re-runnable)
│   ├── 01_tables.sql          9 sequences, 8 tables from Review I + BOOKING_AUDIT, all constraints
│   ├── 02_functions.sql       7 functions
│   ├── 03_procedures.sql      6 stand-alone procedures
│   ├── 04_packages.sql        pkg_rental, pkg_fleet, pkg_reports (spec + body, cursors)
│   ├── 05_triggers.sql        9 triggers (incl. 1 compound trigger)
│   ├── 06_seed_data.sql       5 branches, 6 categories, 20 vehicles, 14 staff, 12 customers, 31 bookings…
│   ├── 07_test_package.sql    pkg_test – 28 automated test cases
│   └── 08_demo_queries.sql    demo script for SQL Developer output screenshots
├── app/                       Flask web front-end (app.py, db.py, templates/, static/)
├── screenshots/               22 output screenshots of the working application
└── README.md
```

## 2. Connect with SQL Developer

| Field | Value |
|---|---|
| Connection name | DriveEase |
| Username / Password | `driveease` / `driveease` |
| Hostname | `localhost` |
| Port | `1521` |
| **Service name** (not SID) | `XEPDB1` |

The schema is already built and loaded. Open the connection and expand **Tables, Packages, Procedures, Functions, Triggers** to see every object.

**To rebuild from scratch** (resets all data): open `sql/run_all.sql` in SQL Developer on the DriveEase connection and press **F5 (Run Script)**.
If SQL Developer cannot find the `@@` files, run 01 → 07 one by one with F5.

**To take output screenshots in SQL Developer:** open `sql/08_demo_queries.sql` and press **F5**. The *Script Output* tab shows:
1. all 28 test cases with PASS/FAIL (`EXEC pkg_test.run_all;`)
2. functions used inside SELECT
3. explicit-cursor reports printed with DBMS_OUTPUT
4. REF CURSOR reports
5. a full booking → pickup → late return run (then rolled back)
6. a trigger blocking a booking
7. the audit trail

> Note: procedures do **not** COMMIT by themselves; the caller commits. That way several calls can form one transaction (NFR "Consistency"). In SQL Developer, type `COMMIT;` after an `EXEC` you want to keep. The web app commits automatically.

## 3. Run the web front-end

```bash
cd ~/Desktop/DriveEase && .venv/bin/python app/app.py
```
Then open **http://127.0.0.1:5050**. The Docker container `oracle-xe` must be running (`docker start oracle-xe`).

If the `.venv` folder is ever missing, recreate it with:
```bash
cd ~/Desktop/DriveEase && python3 -m venv .venv && .venv/bin/pip install -r app/requirements.txt
```

| Page | What it does | Database object called |
|---|---|---|
| Dashboard | fleet status, revenue, dues, overdue returns, audit log | `fn_balance_due`, `fn_late_fee`, `booking_audit` |
| Find a vehicle | availability by city / category / dates (FR-03) | `pkg_rental.search_available` (REF CURSOR) |
| New booking | create booking + advance (FR-04) | `pkg_rental.create_booking` + triggers |
| Booking detail | pickup, return, cancel, payments (FR-05…FR-08) | `record_pickup`, `record_return`, `cancel_booking`, `add_payment` |
| Customers | register + history (FR-01, FR-12) | `sp_register_customer`, `pkg_rental.customer_history` |
| Vehicles | add / retire (FR-02) | `sp_add_vehicle`, `sp_retire_vehicle` |
| Maintenance | schedule / close / auto-schedule (FR-09) | `pkg_fleet.*`, maintenance triggers |
| Reports | revenue, utilisation, top customers, dues (FR-11) | `pkg_reports.*` (REF CURSORs) |
| Branches & staff | branches, employees, category rates (FR-10) | `sp_add_branch`, `sp_add_employee`, `sp_update_category_rate` |
| Test cases | runs all 28 tests inside Oracle | `pkg_test.run_all` |
| Database objects | lists every object, shows its PL/SQL source | `USER_OBJECTS`, `USER_SOURCE` |

Any error raised by a trigger or procedure (ORA-200xx) is shown to the user as a red message.

## 4. PL/SQL objects

### Functions (`02_functions.sql`)
| Function | Purpose | Rule |
|---|---|---|
| `fn_customer_age(cust, date)` | derived attribute *age* | BR-01 |
| `fn_rental_days(booking)` | derived attribute *rental_days*, minimum 1 | BR-04 |
| `fn_rental_amount(booking)` | days × category daily rate | BR-04 |
| `fn_late_fee(booking, what-if date)` | started hours late × late_fee_per_hr | BR-05 |
| `fn_total_paid(booking)` | successful payments − refunds | FR-07 |
| `fn_balance_due(booking)` | rent + late fee − paid | FR-11 |
| `fn_is_vehicle_available(veh, start, end)` | 'Y'/'N', usable in SQL | BR-02, BR-03 |

### Procedures (`03_procedures.sql`)
`sp_register_customer`, `sp_add_branch`, `sp_add_employee`, `sp_add_vehicle`, `sp_retire_vehicle`, `sp_update_category_rate`

### Packages (`04_packages.sql`)
* **pkg_rental**: `search_available` (REF CURSOR), `create_booking`, `record_pickup`, `record_return` (rent + late fee, one-way transfer BR-07, optional settlement), `cancel_booking` (BR-06 refund rule), `add_payment`, `customer_history` (REF CURSOR), `print_customer_history` (explicit parameterised + nested cursors). Uses `%ROWTYPE`, `SAVEPOINT`/`ROLLBACK TO`, `SELECT … FOR UPDATE`, and a private function.
* **pkg_fleet**: `schedule_maintenance`, `update_maintenance`, `auto_schedule_service` (explicit cursor `OPEN / FETCH / EXIT WHEN %NOTFOUND / %ROWCOUNT / CLOSE`).
* **pkg_reports**: `branch_revenue`, `fleet_utilisation`, `top_customers`, `pending_dues` (all REF CURSORs), and `print_branch_summary` (nested cursor FOR loops).
* **pkg_test**: 28 automated test cases.

### Triggers (`05_triggers.sql`)
| Trigger | Timing | Enforces |
|---|---|---|
| `trg_customer_validate` | BEFORE INSERT/UPDATE ON customer | DOB not in future, ≥ 18, licence not expired at registration |
| `trg_booking_eligibility` | BEFORE INSERT/UPDATE ON booking | **BR-01** age ≥ 21 and licence valid to end date; **BR-03** no MAINTENANCE/RETIRED vehicle |
| `trg_booking_no_overlap` | **COMPOUND** trigger ON booking | **BR-02** no double booking (avoids ORA-04091 mutating table) |
| `trg_booking_status_flow` | BEFORE UPDATE OF status | BOOKED→ONGOING/CANCELLED, ONGOING→COMPLETED only |
| `trg_booking_audit` | AFTER INSERT/UPDATE/DELETE | writes BOOKING_AUDIT |
| `trg_vehicle_odometer` | BEFORE UPDATE OF odometer | odometer never decreases (BR-08) |
| `trg_maint_before_insert` | BEFORE INSERT ON maintenance | no maintenance on a RENTED/RETIRED vehicle |
| `trg_maint_vehicle_status` | AFTER INSERT/UPDATE ON maintenance | vehicle → MAINTENANCE / back to AVAILABLE (FR-09) |
| `trg_payment_validate` | BEFORE INSERT ON payment | only REFUND on cancelled bookings; REFUND only on cancelled/completed |

BR-08 (`end_odometer >= start_odometer`) and the date rules are also CHECK constraints on BOOKING.

### Cursors used
* **REF CURSOR (SYS_REFCURSOR)**: `search_available`, `customer_history`, all four `pkg_reports` reports; these are what the web pages display.
* **Explicit cursor with OPEN/FETCH/CLOSE and attributes**: `pkg_fleet.auto_schedule_service`, `pkg_rental.print_customer_history`
* **Parameterised and nested cursor FOR loops**: `print_customer_history`, `pkg_reports.print_branch_summary`
* **Implicit cursor attribute `SQL%ROWCOUNT`**: `sp_retire_vehicle`, `sp_update_category_rate`

## 5. Test cases (`pkg_test.run_all`): 28/28 pass

All tests run inside one transaction and are rolled back, and they create their own test vehicles, so they pass no matter how the data has been changed.

| TC | Area | Test | Expected |
|---|---|---|---|
| 01 | Function | `fn_customer_age` | correct age |
| 02 | Function | `fn_is_vehicle_available` | N for maintenance, Y for free |
| 03 | Procedure | register valid customer | created |
| 04 | Procedure | duplicate licence | ORA-20020 |
| 05 | Procedure | add vehicle | status AVAILABLE |
| 06 | Procedure | retire vehicle with open booking | ORA-20024 |
| 07 | Package | create booking + advance | rent = 3 × 1500 |
| 08 | Cursor | search hides booked vehicle | not listed |
| 09 | Package | pickup | ONGOING / RENTED |
| 10 | Package | return 3 h late, one-way | late fee 300, branch moved, balance 0 |
| 11 | Package | cancel ≥ 24 h before | 100% refund |
| 12 | Package | cancel < 24 h before | 50% refund |
| 13 | Package | booking by a mechanic | ORA-20033 |
| 14 | Trigger | customer aged 19 | ORA-20001 |
| 15 | Trigger | licence expires during rental | ORA-20002 |
| 16 | Trigger | double booking | ORA-20004 |
| 17 | Trigger | vehicle in maintenance | ORA-20003 |
| 18 | Trigger | odometer goes back | ORA-20006 |
| 19 | Trigger | COMPLETED → BOOKED | ORA-20005 |
| 20 | Trigger | payment on cancelled booking | ORA-20008 |
| 21 | Trigger | audit rows written | 3 rows |
| 22 | Trigger | maintenance open/close | MAINTENANCE → AVAILABLE |
| 23 | Trigger | maintenance on rented vehicle | ORA-20007 |
| 24 | Package | end odometer < start | ORA-20051 |
| 25 | Trigger | expired licence at registration | ORA-20013 |
| 26 | Cursor | auto-schedule service | jobs created |
| 27 | Cursor | pending dues report | unpaid rental listed |
| 28 | Cursor | customer history | all bookings fetched |

## 6. Screenshots (`screenshots/`)
`01`–`03` dashboard, fleet, availability search · `04`–`09` triggers/procedures rejecting invalid data ·
`10`–`14` booking life-cycle (create, pickup, late one-way return, full and 50% refunds) · `15`–`16` maintenance ·
`17`–`19` history, reports, admin · `20` all 28 tests passing · `21`–`22` database objects and trigger source.

## 7. Note on time
The Oracle container runs on **UTC**, so `SYSDATE` is 5 h 30 min behind IST. All rules compare against `SYSDATE`, and the web app takes its default dates from the database clock (shown in the sidebar), so everything stays consistent. Just remember that the times shown are database (UTC) times.
