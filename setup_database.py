"""Build (or rebuild) the DriveEase MySQL database from the sql/ folder.

    .venv/bin/python setup_database.py            # tables + objects + sample data
    .venv/bin/python setup_database.py --tests    # ...and run the 28 test cases

Step 0 (00_create_database.sql) needs the MySQL root user; set
MYSQL_ROOT_PASSWORD if your root user has a password (Homebrew default: none).
Everything else runs as the application user driveease / driveease.
"""
import os
import re
import sys
from pathlib import Path

import pymysql

SQL_DIR = Path(__file__).parent / "sql"
FILES = ["01_tables.sql", "02_functions.sql", "03_procedures.sql", "04_modules.sql",
         "05_triggers.sql", "06_seed_data.sql", "07_test_cases.sql"]


def strip_comment(line):
    """Remove a trailing '-- comment' that is not inside a quoted string."""
    in_quote = False
    for i, ch in enumerate(line):
        if ch == "'":
            in_quote = not in_quote
        elif not in_quote and (line.startswith("-- ", i) or line[i:].rstrip() == "--"):
            return line[:i].rstrip()
    return line


def split_statements(text):
    """Split a .sql file into statements, honouring DELIMITER lines like the mysql client."""
    delimiter, buf, out = ";", [], []
    for line in text.splitlines():
        line = strip_comment(line)
        m = re.match(r"^\s*DELIMITER\s+(\S+)\s*$", line, re.I)
        if m:
            delimiter = m.group(1)
            continue
        buf.append(line)
        joined = "\n".join(buf).rstrip()
        if joined.endswith(delimiter):
            stmt = joined[: -len(delimiter)].strip()
            if re.sub(r"--[^\n]*", "", stmt).strip():
                out.append(stmt)
            buf = []
    rest = "\n".join(buf).strip()
    if re.sub(r"--[^\n]*", "", rest).strip():
        out.append(rest)
    return out


def run_file(conn, path):
    with conn.cursor() as cur:
        for stmt in split_statements(path.read_text()):
            cur.execute(stmt)
            while cur.nextset():
                pass
    conn.commit()
    print(f"  ok  {path.name}")


def main():
    root = pymysql.connect(host="localhost", user="root",
                           password=os.environ.get("MYSQL_ROOT_PASSWORD", ""), autocommit=True)
    print("Creating database and user (as root)...")
    run_file(root, SQL_DIR / "00_create_database.sql")
    root.close()

    conn = pymysql.connect(host="localhost", user="driveease", password="driveease",
                           database="driveease", autocommit=True)
    print("Building schema as driveease...")
    for name in FILES:
        run_file(conn, SQL_DIR / name)

    with conn.cursor() as cur:
        cur.execute("""SELECT 'routines', COUNT(*) FROM information_schema.routines WHERE routine_schema = 'driveease'
                       UNION ALL SELECT 'triggers', COUNT(*) FROM information_schema.triggers WHERE trigger_schema = 'driveease'
                       UNION ALL SELECT 'tables/views', COUNT(*) FROM information_schema.tables WHERE table_schema = 'driveease'""")
        for kind, n in cur.fetchall():
            print(f"  {kind:13} {n}")

        if "--tests" in sys.argv:
            cur.execute("CALL run_all_tests()")
            for tc, result, area, test, actual in cur.fetchall():
                print(f"{tc:5} | {result} | {area:9} | {test} | {actual}")
    conn.close()
    print("Done.")


if __name__ == "__main__":
    main()
