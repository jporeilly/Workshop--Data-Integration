import os
import sqlite3

os.makedirs("data", exist_ok=True)
con = sqlite3.connect("data/asset_history.db")
con.execute("""CREATE TABLE IF NOT EXISTS asset_history (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id    TEXT NOT NULL,
    logged_at   TEXT NOT NULL,
    log_text    TEXT NOT NULL
)""")

history = [
    ("PUMP-017", "2025-09-12", "slight rumble on startup, clears after 2 minutes"),
    ("PUMP-017", "2025-11-03", "intermittent vibration under load, bearing checked ok"),
    ("PUMP-017", "2026-01-18", "bearing replaced, work order WO-4412"),
    ("COMP-004", "2025-10-05", "temperature running slightly high 82C, within tolerance"),
    ("COMP-004", "2025-12-14", "cooling fan filter cleaned, temperature normal"),
    ("COMP-004", "2026-02-28", "temperature normal, no issues"),
    ("VALVE-022", "2025-08-20", "valve serviced, seals replaced"),
    ("VALVE-022", "2026-01-09", "operating normally, no issues")
]

con.executemany(
    "INSERT INTO asset_history (asset_id, logged_at, log_text) VALUES (?, ?, ?)",
    history
)
con.commit()
con.close()
print("History database created.")