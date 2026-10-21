"""Open every page of the website against the built database and check it loads.

    .venv/bin/python tests/smoke_test.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "app"))
from app import app  # noqa: E402

PAGES = ["/", "/vehicles", "/search?go=1&start=2030-01-01T10:00&end=2030-01-03T10:00",
         "/customers", "/customers/1001", "/bookings", "/bookings/new", "/bookings/5003",
         "/maintenance", "/reports", "/branches", "/tests", "/database"]

client = app.test_client()
failed = 0
for url in PAGES:
    status = client.get(url).status_code
    print(f"{status}  {url}")
    failed += status != 200
sys.exit(f"{failed} page(s) failed." if failed else 0)
