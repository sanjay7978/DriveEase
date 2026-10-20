"""DriveEase - Vehicle Rental Management System (web front-end).

Flask + PyMySQL. All business rules live in the MySQL database:
pages call stored procedures / functions and display the errors raised
by triggers and procedures (error numbers 200xx) to the user.

Run:  .venv/bin/python app/app.py   ->  http://127.0.0.1:5050
"""
import os
from datetime import datetime, timedelta

from flask import Flask, flash, redirect, render_template, request, url_for

import db

app = Flask(__name__)
app.secret_key = "driveease-dev-key"

PAYMENT_METHODS = ["CASH", "CARD", "UPI", "NETBANKING"]
FUEL_TYPES = ["PETROL", "DIESEL", "CNG", "ELECTRIC"]
ROLES = ["MANAGER", "AGENT", "MECHANIC", "CASHIER"]
SERVICE_TYPES = ["GENERAL", "REPAIR", "TYRE", "ACCIDENT", "INSURANCE"]


# ---------------------------------------------------------------- helpers
def db_now():
    """Current time on the database server (NOW()). All rules compare against
    NOW(), so the form defaults use the same clock."""
    return db.query_one("SELECT NOW() AS now")["now"]


def parse_dt(value):
    """HTML datetime-local / date value -> datetime (or None)."""
    if not value:
        return None
    for fmt in ("%Y-%m-%dT%H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(value, fmt)
        except ValueError:
            pass
    raise ValueError(f"Invalid date: {value}")


def num(value):
    return float(value) if value not in (None, "") else None


def opt_int(value):
    return int(value) if value not in (None, "") else None


def lookups():
    return {
        "branches": db.query("SELECT branch_id, branch_name, city FROM branch ORDER BY branch_id"),
        "categories": db.query("SELECT * FROM vehicle_category ORDER BY category_id"),
        "cities": [r["city"] for r in db.query("SELECT DISTINCT city FROM branch ORDER BY city")],
    }


def run_db_action(fn, success_msg):
    """Run a DB call; flash success or the trigger/procedure error."""
    try:
        result = fn()
        flash(success_msg(result) if callable(success_msg) else success_msg, "success")
        return True, result
    except Exception as exc:  # pymysql errors, ValueError
        flash(db.friendly_error(exc), "error")
        return False, None


@app.template_filter("dt")
def fmt_dt(value, fmt="%d %b %Y %H:%M"):
    return value.strftime(fmt) if value else "–"


@app.template_filter("d")
def fmt_d(value):
    return value.strftime("%d %b %Y") if value else "–"


@app.template_filter("money")
def fmt_money(value):
    if value is None:
        return "–"
    return "₹{:,.0f}".format(value) if float(value).is_integer() else "₹{:,.2f}".format(value)


@app.context_processor
def inject_now():
    return {"now": db_now()}


# ---------------------------------------------------------------- dashboard
@app.route("/")
def dashboard():
    fleet = {r["status"]: r["cnt"] for r in db.query(
        "SELECT status, COUNT(*) cnt FROM vehicle GROUP BY status")}
    bookings = {r["status"]: r["cnt"] for r in db.query(
        "SELECT status, COUNT(*) cnt FROM booking GROUP BY status")}
    revenue = db.query_one("""
        SELECT COALESCE(SUM(CASE WHEN payment_type = 'REFUND' THEN -amount ELSE amount END), 0) AS month_rev
          FROM payment WHERE txn_status = 'SUCCESS' AND payment_date >= DATE_FORMAT(CURDATE(), '%Y-%m-01')""")
    dues = db.query_one("""
        SELECT COALESCE(SUM(fn_balance_due(booking_id)), 0) AS dues FROM booking
         WHERE status IN ('ONGOING', 'COMPLETED')""")
    overdue = db.query("""
        SELECT b.booking_id, c.name, v.reg_number, CONCAT(v.brand, ' ', v.model) AS vehicle, b.end_date,
               ROUND(TIMESTAMPDIFF(MINUTE, b.end_date, NOW()) / 60, 1) AS hours_late,
               fn_late_fee(b.booking_id, NOW()) AS late_fee_now
          FROM booking b JOIN customer c ON c.customer_id = b.customer_id
          JOIN vehicle v ON v.vehicle_id = b.vehicle_id
         WHERE b.status = 'ONGOING' AND b.end_date < NOW() ORDER BY b.end_date""")
    upcoming = db.query("""
        SELECT b.booking_id, b.status, c.name, v.reg_number, CONCAT(v.brand, ' ', v.model) AS vehicle,
               b.start_date, b.end_date, br.branch_name
          FROM booking b JOIN customer c ON c.customer_id = b.customer_id
          JOIN vehicle v ON v.vehicle_id = b.vehicle_id
          JOIN branch br ON br.branch_id = b.pickup_branch_id
         WHERE (b.status = 'BOOKED' AND b.start_date < NOW() + INTERVAL 7 DAY)
            OR (b.status = 'ONGOING' AND b.end_date BETWEEN NOW() AND NOW() + INTERVAL 7 DAY)
         ORDER BY CASE b.status WHEN 'BOOKED' THEN b.start_date ELSE b.end_date END""")
    audit = db.query("SELECT * FROM booking_audit ORDER BY audit_id DESC LIMIT 8")
    return render_template("dashboard.html", fleet=fleet, bookings=bookings,
                           revenue=revenue["month_rev"], dues=dues["dues"],
                           overdue=overdue, upcoming=upcoming, audit=audit)


# ---------------------------------------------------------------- vehicles (FR-02)
@app.route("/vehicles", methods=["GET", "POST"])
def vehicles():
    if request.method == "POST":
        f = request.form
        run_db_action(lambda: db.call("sp_add_vehicle", [
            f["reg_number"], f["brand"], f["model"], opt_int(f["mfg_year"]), f["fuel_type"],
            f["transmission"], opt_int(f["odometer"]) or 0, int(f["category_id"]), int(f["branch_id"])], 1),
            lambda vid: f"Vehicle {vid} added to the fleet (sp_add_vehicle).")
        return redirect(url_for("vehicles"))

    status = request.args.get("status", "")
    branch = request.args.get("branch", "")
    rows = db.query("""
        SELECT v.*, c.category_name, c.daily_rate, b.branch_name, b.city,
               (SELECT COUNT(*) FROM booking x WHERE x.vehicle_id = v.vehicle_id
                   AND x.status IN ('BOOKED','ONGOING')) AS open_bookings
          FROM vehicle v JOIN vehicle_category c ON c.category_id = v.category_id
          JOIN branch b ON b.branch_id = v.branch_id
         WHERE (%(status)s IS NULL OR v.status = %(status)s)
           AND (%(branch)s IS NULL OR v.branch_id = %(branch)s)
         ORDER BY v.vehicle_id""", {"status": status or None, "branch": opt_int(branch)})
    return render_template("vehicles.html", rows=rows, status=status, branch=branch,
                           fuel_types=FUEL_TYPES, **lookups())


@app.post("/vehicles/<int:vehicle_id>/retire")
def retire_vehicle(vehicle_id):
    run_db_action(lambda: db.call("sp_retire_vehicle", [vehicle_id]),
                  f"Vehicle {vehicle_id} retired (sp_retire_vehicle).")
    return redirect(url_for("vehicles"))


# ---------------------------------------------------------------- availability search (FR-03)
@app.route("/search")
def search():
    args = request.args
    default_start = (db_now() + timedelta(days=1)).replace(hour=9, minute=0, second=0, microsecond=0)
    start = args.get("start") or default_start.strftime("%Y-%m-%dT%H:%M")
    end = args.get("end") or (default_start + timedelta(days=2)).strftime("%Y-%m-%dT%H:%M")
    results = None
    if args.get("go"):
        try:
            results = db.result_set("rental_search_available", [
                args.get("city") or None, opt_int(args.get("category")), parse_dt(start), parse_dt(end)])
        except Exception as exc:
            flash(db.friendly_error(exc), "error")
    return render_template("search.html", results=results, start=start, end=end,
                           city=args.get("city", ""), category=args.get("category", ""), **lookups())


# ---------------------------------------------------------------- customers (FR-01, FR-12)
@app.route("/customers", methods=["GET", "POST"])
def customers():
    if request.method == "POST":
        f = request.form
        ok, cid = run_db_action(lambda: db.call("sp_register_customer", [
            f["name"], f["phone"], f["email"] or None, f["license_no"],
            parse_dt(f["license_expiry"]), parse_dt(f["dob"]), f["address"] or None], 1),
            lambda cid: f"Customer {cid} registered (sp_register_customer).")
        return redirect(url_for("customer_detail", customer_id=cid) if ok else url_for("customers"))

    q = request.args.get("q", "").strip()
    rows = db.query("""
        SELECT c.*, fn_customer_age(c.customer_id, NULL) AS age,
               (SELECT COUNT(*) FROM booking b WHERE b.customer_id = c.customer_id) AS rentals
          FROM customer c
         WHERE %(q)s IS NULL OR c.name LIKE CONCAT('%%', %(q)s, '%%')
            OR c.phone LIKE CONCAT('%%', %(q)s, '%%') OR c.license_no LIKE CONCAT('%%', %(q)s, '%%')
         ORDER BY c.customer_id""", {"q": q or None})
    return render_template("customers.html", rows=rows, q=q)


@app.route("/customers/<int:customer_id>")
def customer_detail(customer_id):
    cust = db.query_one("SELECT c.*, fn_customer_age(c.customer_id, NULL) AS age FROM customer c "
                        "WHERE customer_id = %(id)s", {"id": customer_id})
    if not cust:
        flash(f"Customer {customer_id} not found", "error")
        return redirect(url_for("customers"))
    history = db.result_set("rental_customer_history", [customer_id])
    payments = db.query("""
        SELECT p.* FROM payment p JOIN booking b ON b.booking_id = p.booking_id
         WHERE b.customer_id = %(id)s ORDER BY p.payment_date DESC""", {"id": customer_id})
    return render_template("customer_detail.html", c=cust, history=history, payments=payments)


# ---------------------------------------------------------------- bookings (FR-04..FR-08)
@app.route("/bookings")
def bookings():
    status = request.args.get("status", "")
    rows = db.query("""
        SELECT booking_id, status, start_date, end_date, actual_return_date,
               customer, reg_number, vehicle, pickup_branch AS pickup, return_branch AS return_to,
               rent, late_fee, paid, balance
          FROM v_booking_summary
         WHERE %(status)s IS NULL OR status = %(status)s
         ORDER BY booking_id DESC""", {"status": status or None})
    return render_template("bookings.html", rows=rows, status=status)


@app.route("/bookings/new", methods=["GET", "POST"])
def booking_new():
    if request.method == "POST":
        f = request.form
        ok, bid = run_db_action(lambda: db.call("rental_create_booking", [
            int(f["customer_id"]), int(f["vehicle_id"]), int(f["emp_id"]),
            opt_int(f.get("return_branch_id")), parse_dt(f["start"]), parse_dt(f["end"]),
            num(f.get("advance")) or 0, f.get("method") or None], 1),
            lambda bid: f"Booking {bid} created (rental_create_booking).")
        if ok:
            return redirect(url_for("booking_detail", booking_id=bid))
        return redirect(url_for("booking_new", **{k: f.get(k) for k in
                                ("customer_id", "vehicle_id", "emp_id", "start", "end")}))

    a = request.args
    default_start = (db_now() + timedelta(days=1)).replace(hour=9, minute=0, second=0, microsecond=0)
    form = {
        "customer_id": a.get("customer_id", ""), "vehicle_id": a.get("vehicle_id", ""),
        "emp_id": a.get("emp_id", ""),
        "start": a.get("start") or default_start.strftime("%Y-%m-%dT%H:%M"),
        "end": a.get("end") or (default_start + timedelta(days=2)).strftime("%Y-%m-%dT%H:%M"),
    }
    customers_ = db.query("SELECT customer_id, name, phone FROM customer ORDER BY name")
    vehicles_ = db.query("""
        SELECT vehicle_id, reg_number, CONCAT(brand, ' ', model) AS name, status,
               category_name, daily_rate, branch_name
          FROM v_vehicle_catalog WHERE status <> 'RETIRED' ORDER BY vehicle_id""")
    staff = db.query("""SELECT e.emp_id, e.name, e.role, b.branch_name FROM employee e
                        JOIN branch b ON b.branch_id = e.branch_id ORDER BY e.emp_id""")
    return render_template("booking_new.html", form=form, customers=customers_, vehicles=vehicles_,
                           staff=staff, methods=PAYMENT_METHODS, **lookups())


@app.route("/bookings/<int:booking_id>")
def booking_detail(booking_id):
    b = db.query_one("""
        SELECT s.*, s.pickup_branch AS pickup, s.return_branch AS return_to, s.rental_days AS days,
               bk.emp_id, e.name AS agent,
               v.odometer AS vehicle_odometer, v.status AS vehicle_status,
               v.category_name, v.daily_rate, v.late_fee_per_hr, v.security_deposit,
               CASE WHEN s.status = 'ONGOING' THEN fn_late_fee(s.booking_id, NOW()) END AS late_fee_now
          FROM v_booking_summary s
          JOIN booking bk ON bk.booking_id = s.booking_id
          JOIN employee e ON e.emp_id = bk.emp_id
          JOIN v_vehicle_catalog v ON v.vehicle_id = s.vehicle_id
         WHERE s.booking_id = %(id)s""", {"id": booking_id})
    if not b:
        flash(f"Booking {booking_id} not found", "error")
        return redirect(url_for("bookings"))
    payments = db.query("SELECT * FROM payment WHERE booking_id = %(id)s ORDER BY payment_id", {"id": booking_id})
    audit = db.query("SELECT * FROM booking_audit WHERE booking_id = %(id)s ORDER BY audit_id", {"id": booking_id})
    return render_template("booking_detail.html", b=b, payments=payments, audit=audit,
                           methods=PAYMENT_METHODS, now_str=db_now().strftime("%Y-%m-%dT%H:%M"))


@app.post("/bookings/<int:booking_id>/pickup")
def booking_pickup(booking_id):
    run_db_action(lambda: db.call("rental_record_pickup",
                                  [booking_id, int(request.form["start_odometer"])]),
                  "Vehicle handed over - booking is ONGOING (rental_record_pickup).")
    return redirect(url_for("booking_detail", booking_id=booking_id))


@app.post("/bookings/<int:booking_id>/return")
def booking_return(booking_id):
    f = request.form
    run_db_action(lambda: db.call("rental_record_return", [
        booking_id, int(f["end_odometer"]), parse_dt(f["return_date"]) or db_now(),
        f.get("method") or None], 1),
        lambda due: f"Vehicle returned (rental_record_return). Balance due: ₹{due:,.2f}")
    return redirect(url_for("booking_detail", booking_id=booking_id))


@app.post("/bookings/<int:booking_id>/cancel")
def booking_cancel(booking_id):
    run_db_action(lambda: db.call("rental_cancel_booking", [booking_id], 1),
                  lambda refund: f"Booking cancelled (rental_cancel_booking). Refund: ₹{refund:,.2f}")
    return redirect(url_for("booking_detail", booking_id=booking_id))


@app.post("/bookings/<int:booking_id>/payment")
def booking_payment(booking_id):
    f = request.form
    run_db_action(lambda: db.call("rental_add_payment", [
        booking_id, num(f["amount"]), f["method"], f["payment_type"]], 1),
        lambda pid: f"Payment {pid} recorded (rental_add_payment).")
    return redirect(url_for("booking_detail", booking_id=booking_id))


# ---------------------------------------------------------------- maintenance (FR-09)
@app.route("/maintenance", methods=["GET", "POST"])
def maintenance():
    if request.method == "POST":
        f = request.form
        run_db_action(lambda: db.call("fleet_schedule_maintenance", [
            int(f["vehicle_id"]), f["service_type"], f["description"] or None,
            parse_dt(f["service_date"]) or db_now()], 1),
            lambda mid: f"Maintenance job {mid} scheduled (fleet_schedule_maintenance).")
        return redirect(url_for("maintenance"))

    rows = db.query("""
        SELECT m.*, v.reg_number, CONCAT(v.brand, ' ', v.model) AS vehicle, v.status AS vehicle_status,
               b.branch_name
          FROM maintenance m JOIN vehicle v ON v.vehicle_id = m.vehicle_id
          JOIN branch b ON b.branch_id = v.branch_id
         ORDER BY m.maint_status = 'DONE', m.service_date DESC""")
    vehicles_ = db.query("""SELECT vehicle_id, reg_number, CONCAT(brand, ' ', model) AS name, status
                              FROM vehicle WHERE status <> 'RETIRED' ORDER BY vehicle_id""")
    return render_template("maintenance.html", rows=rows, vehicles=vehicles_, service_types=SERVICE_TYPES,
                           today=db_now().strftime("%Y-%m-%d"))


@app.post("/maintenance/<int:maint_id>/update")
def maintenance_update(maint_id):
    f = request.form
    run_db_action(lambda: db.call("fleet_update_maintenance",
                                  [maint_id, f["status"], num(f.get("cost"))]),
                  f"Job {maint_id} set to {f['status']} (fleet_update_maintenance).")
    return redirect(url_for("maintenance"))


@app.post("/maintenance/auto")
def maintenance_auto():
    run_db_action(lambda: db.call("fleet_auto_schedule_service", [], 1),
                  lambda n: f"{n} periodic service job(s) created (fleet_auto_schedule_service).")
    return redirect(url_for("maintenance"))


# ---------------------------------------------------------------- reports (FR-11)
@app.route("/reports")
def reports():
    months = opt_int(request.args.get("months")) or 6
    days = opt_int(request.args.get("days")) or 30
    revenue = db.result_set("report_branch_revenue", [months])
    pivot, month_list = {}, []
    for r in revenue:
        pivot.setdefault(r["branch_name"], {})[r["month"]] = r["revenue"]
        if r["month"] not in month_list:
            month_list.append(r["month"])
    month_list.sort()
    return render_template(
        "reports.html", months=months, days=days, revenue=revenue, pivot=pivot, month_list=month_list,
        utilisation=db.result_set("report_fleet_utilisation", [days]),
        top=db.result_set("report_top_customers", [5]),
        dues=db.result_set("report_pending_dues"),
        summary=db.result_set("report_branch_summary"))


# ---------------------------------------------------------------- branches & staff (FR-10)
@app.route("/branches", methods=["GET", "POST"])
def branches():
    if request.method == "POST":
        f = request.form
        kind = f.get("kind")
        if kind == "branch":
            run_db_action(lambda: db.call("sp_add_branch", [
                f["branch_name"], f["city"], f["address"], f["phone"], f["email"] or None], 1),
                lambda bid: f"Branch {bid} added (sp_add_branch).")
        elif kind == "employee":
            run_db_action(lambda: db.call("sp_add_employee", [
                f["name"], f["role"], f["phone"], f["email"] or None, num(f["salary"]),
                int(f["branch_id"])], 1),
                lambda eid: f"Employee {eid} added (sp_add_employee).")
        elif kind == "rate":
            run_db_action(lambda: db.call("sp_update_category_rate", [
                int(f["category_id"]), num(f["daily_rate"]), num(f.get("late_fee"))]),
                "Category rate updated (sp_update_category_rate).")
        return redirect(url_for("branches"))

    branch_rows = db.query("""
        SELECT b.*, (SELECT COUNT(*) FROM vehicle v WHERE v.branch_id = b.branch_id
                        AND v.status <> 'RETIRED') AS vehicles,
               (SELECT COUNT(*) FROM employee e WHERE e.branch_id = b.branch_id) AS staff
          FROM branch b ORDER BY b.branch_id""")
    staff = db.query("""SELECT e.*, b.branch_name FROM employee e
                        JOIN branch b ON b.branch_id = e.branch_id ORDER BY e.emp_id""")
    return render_template("branches.html", branch_rows=branch_rows, staff=staff, roles=ROLES, **lookups())


# ---------------------------------------------------------------- test cases
@app.route("/tests", methods=["GET", "POST"])
def tests():
    results, summary = None, None
    if request.method == "POST" or request.args.get("run"):
        results = []
        try:
            rows = db.run_tests()
            results = [r for r in rows if r["tc"] != "TOTAL"]
            summary = next((r for r in rows if r["tc"] == "TOTAL"), None)
        except Exception as exc:
            flash(db.friendly_error(exc), "error")
    return render_template("tests.html", results=results, summary=summary)


# ---------------------------------------------------------------- database objects
OBJECT_ORDER = ["BASE TABLE", "VIEW", "FUNCTION", "PROCEDURE", "TRIGGER"]


@app.route("/database")
def database():
    objects = db.query("""
        SELECT table_type AS object_type, table_name AS object_name, NULL AS detail
          FROM information_schema.tables WHERE table_schema = DATABASE()
        UNION ALL
        SELECT routine_type, routine_name, NULL
          FROM information_schema.routines WHERE routine_schema = DATABASE()
        UNION ALL
        SELECT 'TRIGGER', trigger_name, CONCAT(action_timing, ' ', event_manipulation, ' ON ', event_object_table)
          FROM information_schema.triggers WHERE trigger_schema = DATABASE()""")
    objects.sort(key=lambda o: (OBJECT_ORDER.index(o["object_type"]), o["object_name"]))

    name, otype, source = request.args.get("name"), request.args.get("type"), None
    known = {(o["object_type"], o["object_name"]) for o in objects}
    if name and (otype, name) in known:
        kind = {"BASE TABLE": "TABLE"}.get(otype, otype)
        row = db.query_one(f"SHOW CREATE {kind} `{name}`")
        source = next(v for k, v in row.items() if k.startswith("Create") or k.startswith("SQL Original"))
        if kind == "TRIGGER":
            source = row["SQL Original Statement"]
    return render_template("database.html", objects=objects, source=source, name=name, otype=otype)


if __name__ == "__main__":
    app.run(debug=True, port=int(os.environ.get("PORT", 5050)))
