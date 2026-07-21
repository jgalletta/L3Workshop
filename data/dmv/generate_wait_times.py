#!/usr/bin/env python3
"""Generate a realistic DMV real-time wait-times dataset.

Produces one row per (office, service_type) observation on a fixed cadence
(every 15 minutes) across a span of days. Wait times follow realistic
patterns: open hours only, lunchtime + late-afternoon peaks, Monday/Friday
and pre-holiday surges, longer waits for road tests & new licenses, and
random noise. This is the raw "wait time reading" feed you'd stream in
real time.
"""
import csv
import math
from datetime import datetime, timedelta, timezone

# ---- Reference data -------------------------------------------------------
# 8 California DMV offices (office dimension lives in its own table; we carry
# the key + a few denormalized attributes useful for streaming consumers).
OFFICES = [
    # office_id, name, city, region, num_windows, lat, lon
    ("DMV-001", "Oakland Claremont",   "Oakland",       "Bay Area",       12, 37.8112, -122.2506),
    ("DMV-002", "San Jose DTC",        "San Jose",      "Bay Area",       18, 37.3305, -121.8880),
    ("DMV-003", "Sacramento Broadway", "Sacramento",    "Central Valley", 14, 38.5560, -121.4870),
    ("DMV-004", "Fresno North",        "Fresno",        "Central Valley", 10, 36.8300, -119.7870),
    ("DMV-005", "LA Hollywood",        "Los Angeles",   "SoCal",          20, 34.0900, -118.3290),
    ("DMV-006", "San Diego Normal Hts","San Diego",     "SoCal",          16, 32.7610, -117.1250),
    ("DMV-007", "Bakersfield SW",      "Bakersfield",   "Central Valley",  8, 35.3410, -119.0730),
    ("DMV-008", "Santa Rosa",          "Santa Rosa",    "Bay Area",        9, 38.4400, -122.7140),
]

# service_type_id, label, base wait (min), variability, appt-eligible
SERVICE_TYPES = [
    ("SVC-DL-RENEW",  "Driver License Renewal",   12, 6,  True),
    ("SVC-DL-NEW",    "New Driver License",        28, 12, True),
    ("SVC-ROAD-TEST", "Behind-the-Wheel Test",     35, 15, True),
    ("SVC-VEH-REG",   "Vehicle Registration",      18, 9,  True),
    ("SVC-TITLE",     "Title Transfer",            22, 10, True),
    ("SVC-ID-CARD",   "State ID Card",             10, 5,  True),
    ("SVC-WALKIN",    "General Walk-In",           40, 20, False),
]

# 2024 US federal-ish holidays that spike pre-holiday demand (month, day)
PRE_HOLIDAY_SURGE_DATES = {(1, 12), (2, 16), (5, 24)}  # day before long weekends

CADENCE_MIN = 15          # a reading every 15 minutes per (office, service)
OPEN_HOUR, CLOSE_HOUR = 8, 17   # 08:00–17:00 local
START = datetime(2024, 1, 8, tzinfo=timezone.utc)   # a Monday
DAYS = 14                  # two weeks of history

# deterministic pseudo-random (no external deps, reproducible)
def rnd(seed):
    x = math.sin(seed * 12.9898) * 43758.5453
    return x - math.floor(x)

def time_of_day_factor(hour, minute):
    """Peaks near lunch (12:30) and late afternoon (16:00); calmer at open."""
    t = hour + minute / 60.0
    lunch = math.exp(-((t - 12.5) ** 2) / 1.2)
    late = math.exp(-((t - 16.0) ** 2) / 2.0)
    open_calm = 0.55 if t < 9 else 1.0
    return open_calm * (0.6 + 0.9 * lunch + 0.7 * late)

def day_factor(dt):
    wd = dt.weekday()  # 0=Mon
    base = {0: 1.35, 1: 1.0, 2: 0.95, 3: 1.0, 4: 1.25}.get(wd, 0.0)  # closed weekends
    if (dt.month, dt.day) in PRE_HOLIDAY_SURGE_DATES:
        base *= 1.6
    return base

rows = []
seed = 0
for day in range(DAYS):
    date = START + timedelta(days=day)
    if date.weekday() >= 5:  # closed Sat/Sun
        continue
    df = day_factor(date)
    for oi, (office_id, name, city, region, windows, lat, lon) in enumerate(OFFICES):
        # bigger offices absorb load -> shorter relative waits
        capacity_relief = 12.0 / windows
        for si, (svc_id, svc_label, base, var, appt_ok) in enumerate(SERVICE_TYPES):
            hour, minute = OPEN_HOUR, 0
            while hour < CLOSE_HOUR or (hour == CLOSE_HOUR and minute == 0):
                ts = date.replace(hour=hour, minute=minute)
                seed += 1
                tod = time_of_day_factor(hour, minute)
                noise = (rnd(seed) - 0.5) * 2 * var
                wait = base * tod * df * capacity_relief + noise
                wait = max(0.0, wait)
                # queue length loosely tracks wait / avg service time
                queue_len = max(0, int(wait / 6.0 + (rnd(seed + 7) - 0.5) * 3))
                # people currently being served, capped by windows
                serving = min(windows, max(0, int(queue_len * 0.4 + rnd(seed + 3) * 2)))
                status = ("HIGH" if wait > 45 else "MODERATE" if wait > 20 else "LOW")
                rows.append({
                    "reading_id": f"{office_id}-{svc_id}-{ts.strftime('%Y%m%d%H%M')}",
                    "office_id": office_id,
                    "office_name": name,
                    "city": city,
                    "region": region,
                    "num_windows": windows,
                    "latitude": round(lat, 4),
                    "longitude": round(lon, 4),
                    "service_type_id": svc_id,
                    "service_type": svc_label,
                    "appointment_eligible": appt_ok,
                    "observed_at": ts.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "wait_minutes": round(wait, 1),
                    "queue_length": queue_len,
                    "windows_serving": serving,
                    "congestion_status": status,
                    "source": "kiosk-sensor",
                })
                minute += CADENCE_MIN
                if minute >= 60:
                    minute -= 60
                    hour += 1

fieldnames = list(rows[0].keys())
out = "/Users/j.galletta/Documents/L3Workshop/L3Workshop/data/dmv/dmv_wait_times.csv"
with open(out, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(rows)

print(f"Wrote {len(rows):,} rows to {out}")
print(f"Offices: {len(OFFICES)}  Service types: {len(SERVICE_TYPES)}  Days: {DAYS} (weekdays only)")
