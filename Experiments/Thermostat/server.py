# server.py
from fastapi import FastAPI, Query
from fastapi.responses import FileResponse, PlainTextResponse
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from collections import deque
from typing import List, Dict
import asyncio, socket, json, csv, os, sys, time

# --------- CONFIG ----------
HOST = "192.168.1.26"          # thermostat IP
PORT = 23                      # thermostat TCP port
POLL_PERIOD = 1.0              # seconds
CSV_PATH = "/home/jrydberg/Documents/Projects/thermostat_data.csv"

# Which fields to duplicate per channel into _ch0/_ch1 columns:
FIELDS = [
    "temperature", "i_tec", "pid_output",
    "adc", "sens", "i_set", "dac_value", "dac_feedback",
    "tec_i", "tec_u_meas", "pid_engaged", "current_swapped", "interval",
]
# ---------------------------

history = deque(maxlen=60000)  # ~10 minutes at 1Hz (for /report and /series)

def log(*a):
    print("[thermostat]", *a, file=sys.stderr, flush=True)

def send_scpi_command(host: str, port: int, command: str) -> str:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(3.0)
        sock.connect((host, port))
        sock.sendall(command.encode())
        return sock.recv(16384).decode().strip()

def now_iso_ms():
    now = datetime.now(timezone.utc)
    return now.isoformat(), int(now.timestamp() * 1000)

def ensure_csv_header_combined():
    os.makedirs(os.path.dirname(CSV_PATH) or ".", exist_ok=True)
    need_header = not os.path.exists(CSV_PATH) or os.path.getsize(CSV_PATH) == 0
    if need_header:
        header = ["time", "ts"]
        for name in FIELDS:
            header.append(f"{name}_ch0")
            header.append(f"{name}_ch1")
        with open(CSV_PATH, "w", newline="") as f:
            csv.writer(f).writerow(header)
        log("created CSV header at", CSV_PATH)

def append_csv_combined(rows: List[Dict]):
    """
    rows: list of dicts for this single poll, one per channel (e.g., 0 and 1).
    Writes exactly one CSV row with _ch0/_ch1 columns.
    """
    ensure_csv_header_combined()

    # map rows by channel (expect integers 0/1)
    by_ch = {}
    for r in rows:
        try:
            ch = int(r.get("channel"))
        except Exception:
            continue
        by_ch[ch] = r

    # pick timestamp from any present row
    iso_time, ts_ms = rows[0].get("time"), rows[0].get("ts")

    out = [iso_time, ts_ms]
    for name in FIELDS:
        v0 = by_ch.get(0, {}).get(name)
        v1 = by_ch.get(1, {}).get(name)
        # convert booleans to 0/1 (Grafana likes numeric)
        if isinstance(v0, bool): v0 = int(v0)
        if isinstance(v1, bool): v1 = int(v1)
        out.extend([v0, v1])

    with open(CSV_PATH, "a", newline="") as f:
        csv.writer(f).writerow(out)
        f.flush()

def poll_once() -> List[Dict]:
    """Read device once, enrich timestamps, keep in memory, append to CSV (combined)."""
    raw = send_scpi_command(HOST, PORT, "report\n")
    arr = json.loads(raw)  # list of per-channel dicts
    iso, ms = now_iso_ms()
    for d in arr:
        d["time"] = iso          # ISO-8601 (UTC)
        d["ts"] = ms             # epoch ms (handy if you need it elsewhere)
    history.append(arr)
    append_csv_combined(arr)
    return arr

async def poll_loop():
    """Precise ~1 Hz loop using monotonic scheduling."""
    period = POLL_PERIOD
    next_t = time.monotonic()
    while True:
        try:
            poll_once()
        except Exception as e:
            log("poll error:", repr(e))
        next_t += period
        await asyncio.sleep(max(0, next_t - time.monotonic()))

@asynccontextmanager
async def lifespan(app: FastAPI):
    ensure_csv_header_combined()
    asyncio.create_task(poll_loop())
    yield
    # (no special shutdown)

app = FastAPI(lifespan=lifespan)

# ---------- ROUTES ----------

@app.get("/report")
def latest():
    """Latest poll flattened (two dicts, one per channel)."""
    return history[-1] if history else []

@app.get("/series")
def series(_from: int = Query(..., alias="from"), _to: int = Query(..., alias="to")):
    """Return all flattened points between from/to (ms since epoch)."""
    out: List[Dict] = []
    for batch in history:
        if not batch: 
            continue
        ts = batch[0].get("ts", 0)
        if _from <= ts <= _to:
            out.extend(batch)
    return out

@app.get("/data.csv")
def csv_file():
    """Serve the combined CSV (one row per poll)."""
    ensure_csv_header_combined()
    return FileResponse(CSV_PATH, media_type="text/csv", filename=os.path.basename(CSV_PATH))

@app.post("/save_once")
def save_once():
    """Force one immediate device read + CSV write (debugging)."""
    try:
        arr = poll_once()
        # we wrote ONE row to CSV even if there were 2 channels
        return {"wrote_rows": 1, "channels_in_poll": len(arr), "csv": CSV_PATH}
    except Exception as e:
        return PlainTextResponse(str(e), status_code=500)
