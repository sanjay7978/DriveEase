"""Thin helper around PyMySQL for the DriveEase web app.

Every business operation is done by the stored routines in MySQL
(procedures, functions, modules, triggers); this module only calls them.
"""
import os

import pymysql
import pymysql.cursors

DB_HOST = os.environ.get("DRIVEEASE_DB_HOST", "localhost")
DB_USER = os.environ.get("DRIVEEASE_DB_USER", "driveease")
DB_PASSWORD = os.environ.get("DRIVEEASE_DB_PASSWORD", "driveease")
DB_NAME = os.environ.get("DRIVEEASE_DB_NAME", "driveease")


def connect():
    """Open a new connection. autocommit is OFF so every page action is one transaction."""
    return pymysql.connect(host=DB_HOST, user=DB_USER, password=DB_PASSWORD, database=DB_NAME,
                           cursorclass=pymysql.cursors.DictCursor, autocommit=False)


def _drain(cur):
    while cur.nextset():
        pass


def query(sql, params=None):
    """Run a SELECT (use %(name)s placeholders) and return a list of dicts."""
    with connect() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return list(cur.fetchall())


def query_one(sql, params=None):
    rows = query(sql, params)
    return rows[0] if rows else None


def result_set(proc_name, args=()):
    """CALL a procedure that returns a result set and give back its rows."""
    placeholders = ", ".join(["%s"] * len(args))
    with connect() as conn, conn.cursor() as cur:
        cur.execute(f"CALL {proc_name}({placeholders})", list(args))
        rows = list(cur.fetchall())
        _drain(cur)
        return rows


def call(proc_name, args, n_out=0):
    """CALL a procedure inside one transaction.

    `args` are the IN parameters; `n_out` trailing OUT parameters are bound
    to session variables and returned. Commits on success, rolls back on error.
    """
    outs = [f"@out{i}" for i in range(n_out)]
    params = ", ".join(["%s"] * len(args) + outs)
    with connect() as conn, conn.cursor() as cur:
        try:
            cur.execute(f"CALL {proc_name}({params})", list(args))
            _drain(cur)
            values = []
            if outs:
                cur.execute("SELECT " + ", ".join(f"{o} AS o{i}" for i, o in enumerate(outs)))
                row = cur.fetchone()
                values = [row[f"o{i}"] for i in range(n_out)]
            conn.commit()
        except Exception:
            conn.rollback()
            raise
    if not values:
        return None
    return values[0] if len(values) == 1 else values


def run_tests():
    """CALL run_all_tests() and return its rows (the procedure rolls back its own changes)."""
    return result_set("run_all_tests")


def friendly_error(exc):
    """Turn a PyMySQL error into one clean line, e.g. 'Error 20004: Vehicle is already booked...'."""
    if isinstance(exc, pymysql.err.MySQLError) and len(exc.args) >= 2:
        return f"Error {exc.args[0]}: {exc.args[1]}"
    return str(exc).splitlines()[0] if str(exc) else exc.__class__.__name__
