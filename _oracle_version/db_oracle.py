"""Thin helper around python-oracledb for the DriveEase web app.

Every business operation is done by the PL/SQL objects in the database
(packages, procedures, functions, triggers); this module only calls them.
"""
import os
import re

import oracledb

DB_USER = os.environ.get("DRIVEEASE_DB_USER", "driveease")
DB_PASSWORD = os.environ.get("DRIVEEASE_DB_PASSWORD", "driveease")
DB_DSN = os.environ.get("DRIVEEASE_DB_DSN", "localhost:1521/XEPDB1")


def connect():
    """Open a new connection (thin mode - no Oracle client install needed)."""
    return oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN)


def _rows(cursor):
    cols = [d[0].lower() for d in cursor.description]
    return [dict(zip(cols, row)) for row in cursor]


def query(sql, params=None):
    """Run a SELECT and return a list of dicts."""
    with connect() as conn, conn.cursor() as cur:
        cur.execute(sql, params or {})
        return _rows(cur)


def query_one(sql, params=None):
    rows = query(sql, params)
    return rows[0] if rows else None


def refcursor(func_name, args=None):
    """Call a PL/SQL function returning SYS_REFCURSOR and return its rows."""
    with connect() as conn, conn.cursor() as cur:
        rc = cur.callfunc(func_name, oracledb.DB_TYPE_CURSOR, args or [])
        return _rows(rc)


def call(proc_name, args, out_types=()):
    """Call a PL/SQL procedure inside one transaction.

    `args` are the IN parameters; `out_types` lists the Python types of the
    trailing OUT parameters. Commits on success, rolls back on any error,
    and returns the OUT values.
    """
    with connect() as conn, conn.cursor() as cur:
        outs = [cur.var(t) for t in out_types]
        try:
            cur.callproc(proc_name, list(args) + outs)
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        values = [o.getvalue() for o in outs]
        return values[0] if len(values) == 1 else values


def run_tests():
    """Execute pkg_test.run_all and return its DBMS_OUTPUT lines."""
    with connect() as conn, conn.cursor() as cur:
        cur.callproc("dbms_output.enable", [None])
        cur.callproc("pkg_test.run_all")
        lines = []
        line_var = cur.var(str)
        status_var = cur.var(int)
        while True:
            cur.callproc("dbms_output.get_line", (line_var, status_var))
            if status_var.getvalue() != 0:
                break
            lines.append(line_var.getvalue() or "")
        conn.rollback()
        return lines


def friendly_error(exc):
    """Turn 'ORA-20004: Vehicle is already booked...' plus stack into one clean line."""
    text = str(exc)
    m = re.search(r"ORA-(\d{5}): ([^\n]*)", text)
    if not m:
        return text.splitlines()[0]
    code, msg = m.groups()
    # strip the ORA-06512 "at line" noise that follows user errors
    msg = re.sub(r"ORA-06512.*", "", msg).strip()
    return f"ORA-{code}: {msg}"
