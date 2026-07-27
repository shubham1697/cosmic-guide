#!/usr/bin/env python3
"""Build dashboard/data/dashboard.json from audit.log, features.yaml, the DB and LLM pings.

Run from the HOST so the DB (localhost:5432) and LAN LLMs are reachable:
    python dashboard/generate.py            # one snapshot
    python dashboard/generate.py --watch     # regenerate every 5s

The static dashboard (index.html) fetches the JSON this produces.
"""
import os
import sys
import json
import time
import http.client
from collections import defaultdict
from datetime import datetime, timezone, date
from statistics import mean

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

try:
    import yaml
except ImportError:
    sys.exit("Missing dependency: pip install pyyaml")

HERE = os.path.join(ROOT, "dashboard")
DATA = os.path.join(HERE, "data")
AUDIT = os.path.join(ROOT, "backend", "logs", "audit.log")
FEATURES_YAML = os.path.join(HERE, "features.yaml")
ENDPOINTS_YAML = os.path.join(HERE, "endpoints.yaml")


def _p95(values):
    if not values:
        return 0.0
    ordered = sorted(values)
    idx = min(len(ordered) - 1, int(round(0.95 * (len(ordered) - 1))))
    return round(ordered[idx], 1)


def _epoch(ts):
    try:
        return datetime.fromisoformat(ts).timestamp()
    except Exception:
        return 0.0


def parse_audit(path, recent_n=300, dup_window_s=2.0):
    inbound, outbound = [], []
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                (inbound if rec.get("type") == "inbound" else outbound).append(rec)

    by_path = defaultdict(list)
    by_status = defaultdict(int)
    by_method = defaultdict(int)
    over_time = defaultdict(int)
    errors = []
    for r in inbound:
        by_path[r.get("path", "?")].append(r.get("duration_ms") or 0.0)
        by_status[str(r.get("status"))] += 1
        by_method[r.get("method", "?")] += 1
        bucket = (r.get("ts") or "")[:16]
        if bucket:
            over_time[bucket] += 1
        if (r.get("status") or 0) >= 400 or r.get("error"):
            errors.append(r)

    endpoints = sorted(
        ({"path": p, "count": len(v),
          "avg_ms": round(mean(v), 1) if v else 0,
          "p95_ms": _p95(v),
          "max_ms": round(max(v), 1) if v else 0} for p, v in by_path.items()),
        key=lambda e: e["count"], reverse=True,
    )

    slowest = sorted(
        ({"path": r.get("path"), "query": r.get("query"),
          "ms": r.get("duration_ms"), "status": r.get("status"),
          "ts": r.get("ts")} for r in inbound),
        key=lambda e: e["ms"] or 0, reverse=True,
    )[:20]

    duplicates = []
    buckets = defaultdict(list)
    for r in inbound:
        buckets[(r.get("method"), r.get("path"), r.get("query"))].append(r.get("ts"))
    for key, stamps in buckets.items():
        stamps = sorted(_epoch(t) for t in stamps if t)
        lo = 0
        for hi in range(len(stamps)):
            while stamps[hi] - stamps[lo] > dup_window_s:
                lo += 1
            if hi - lo + 1 >= 3:
                duplicates.append({"method": key[0], "path": key[1],
                                   "query": key[2], "count": hi - lo + 1,
                                   "window_s": dup_window_s})
                break

    out_by = defaultdict(lambda: {"count": 0, "ok": 0, "ms": []})
    for r in outbound:
        b = out_by[r.get("service", "?")]
        b["count"] += 1
        if (r.get("status") or 0) == 200:
            b["ok"] += 1
        if r.get("duration_ms") is not None:
            b["ms"].append(r["duration_ms"])
    outbound_stats = [
        {"service": s, "count": b["count"],
         "success_rate": round(100 * b["ok"] / b["count"], 1) if b["count"] else 0,
         "avg_ms": round(mean(b["ms"]), 1) if b["ms"] else 0,
         "p95_ms": _p95(b["ms"])}
        for s, b in out_by.items()
    ]

    return {
        "total_inbound": len(inbound),
        "total_outbound": len(outbound),
        "error_count": len(errors),
        "by_status": dict(by_status),
        "by_method": dict(by_method),
        "over_time": dict(sorted(over_time.items())),
        "endpoints": endpoints,
        "slowest": slowest,
        "duplicates": duplicates,
        "errors": [{"path": e.get("path"), "status": e.get("status"),
                    "error": e.get("error"), "ts": e.get("ts")} for e in errors[-50:]],
        "outbound": outbound_stats,
        "recent": inbound[-recent_n:],
    }


def load_features(path):
    doc = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            doc = yaml.safe_load(handle) or {}
    sections = doc.get("sections", [])
    totals = defaultdict(int)
    for section in sections:
        for item in section.get("items", []):
            totals[item.get("status", "pending")] += 1
            totals["total"] += 1
    return {"sections": sections, "totals": dict(totals),
            "tracks": doc.get("tracks", [])}


def db_status():
    try:
        from database.connection import SessionLocal
        from database.db_service import get_content_status
        db = SessionLocal()
        try:
            return {"ok": True, "status": get_content_status(db, date.today())}
        finally:
            db.close()
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def _ping(host, path, https=False, timeout=4):
    start = time.perf_counter()
    try:
        conn_cls = http.client.HTTPSConnection if https else http.client.HTTPConnection
        conn = conn_cls(host, timeout=timeout)
        conn.request("GET", path)
        resp = conn.getresponse()
        resp.read()
        conn.close()
        return {"ok": resp.status == 200, "status": resp.status,
                "ms": round((time.perf_counter() - start) * 1000, 1)}
    except Exception as exc:
        return {"ok": False, "error": str(exc),
                "ms": round((time.perf_counter() - start) * 1000, 1)}


def llm_health():
    try:
        from database.config import (OLLAMA_HOST, IPHONE_LLM_BASE_URL,
                                     GEMINI_API_KEY, OLLAMA_MODEL, IPHONE_LLM_MODEL)
    except Exception as exc:
        return {"error": str(exc)}
    scheme, _, rest = IPHONE_LLM_BASE_URL.partition("://")
    host_port, _, prefix = rest.partition("/")
    iphone_path = "/" + (prefix.rstrip("/") + "/models").lstrip("/")
    return {
        "ollama": {**_ping(OLLAMA_HOST, "/api/tags"),
                   "host": OLLAMA_HOST, "model": OLLAMA_MODEL},
        "iphone": {**_ping(host_port, iphone_path, https=(scheme == "https")),
                   "url": IPHONE_LLM_BASE_URL, "model": IPHONE_LLM_MODEL},
        "gemini": {"ok": bool(GEMINI_API_KEY), "configured": bool(GEMINI_API_KEY)},
    }


def load_endpoints(path, seen_paths):
    doc = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as handle:
            doc = yaml.safe_load(handle) or {}
    endpoints = doc.get("endpoints", [])
    for e in endpoints:
        e["seen"] = e.get("path") in seen_paths
    return endpoints


def build():
    os.makedirs(DATA, exist_ok=True)
    logs = parse_audit(AUDIT)
    seen = {e["path"] for e in logs["endpoints"]}
    payload = {
        "logs": logs,
        "features": load_features(FEATURES_YAML),
        "db": db_status(),
        "llm": llm_health(),
        "endpoints": load_endpoints(ENDPOINTS_YAML, seen),
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    out = os.path.join(DATA, "dashboard.json")
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, default=str)
    print("wrote", out, payload["generated_at"])


def main():
    if "--watch" in sys.argv:
        while True:
            try:
                build()
            except Exception as exc:
                print("generate error:", exc)
            time.sleep(5)
    else:
        build()


if __name__ == "__main__":
    main()
