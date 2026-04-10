import sqlite3, os

os.makedirs("data", exist_ok=True)
con = sqlite3.connect("data/maintenance_log.db")

# maintenance_log: one row per engineer observation
con.execute('''CREATE TABLE IF NOT EXISTS maintenance_log (
    log_id      TEXT PRIMARY KEY,
    asset_id    TEXT NOT NULL,
    logged_at   TEXT NOT NULL,
    engineer    TEXT NOT NULL,
    log_text    TEXT NOT NULL,
    processed   INTEGER NOT NULL DEFAULT 0)''')

# assessed_log: populated by the PDI transformation
con.execute('''CREATE TABLE IF NOT EXISTS assessed_log (
    log_id           TEXT PRIMARY KEY,
    asset_id         TEXT NOT NULL,
    logged_at        TEXT,
    log_text         TEXT,
    priority         TEXT,
    fault_type       TEXT,
    pattern          TEXT,
    assessment       TEXT,
    confidence       INTEGER,
    parse_error      TEXT DEFAULT 'N',
    response_time_ms INTEGER,
    assessed_at      TEXT DEFAULT (datetime('now')))''')

# Five sample log entries across four assets
log_entries = [
    ("L-1001","PUMP-017","2026-04-07 08:14:00","J.Walsh",
     "Rougher than usual on startup, louder than before the January maintenance. Vibration settling after ~3 minutes.", 0),
    ("L-1002","COMP-004","2026-04-07 09:02:00","S.Okafor",
     "High temperature alarm triggered at 09:00. Reading: 94C. Limit is 85C. No prior warnings this shift.", 0),
    ("L-1003","FAN-011","2026-04-07 10:31:00","T.Marsh",
     "Fan running normally. Slight hum noted but within normal range. No action.", 0),
    ("L-1004","PUMP-017","2026-04-07 11:45:00","J.Walsh",
     "Vibration increased since this morning. Getting worse through the shift.", 0),
    ("L-1005","VALVE-022","2026-04-07 13:10:00","R.Nkosi",
     "Valve sticking on close. Takes 3-4 attempts. Never seen this before.", 0),
]
con.executemany(
    "INSERT OR IGNORE INTO maintenance_log (log_id,asset_id,logged_at,engineer,log_text,processed) VALUES (?,?,?,?,?,?)",
    log_entries)
con.commit()
con.close()
print("maintenance_log.db created:", len(log_entries), "entries.")