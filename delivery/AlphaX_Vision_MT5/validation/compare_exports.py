"""Compare TradingView's diagnostic CSV with the MT5 closed-bar CSV.

python compare_exports.py tradingview.csv metatrader.csv --report comparison.json
No dependencies beyond Python 3.11+. Does not contact either platform.
"""
import argparse
import csv
import datetime as dt
import json
import math
from pathlib import Path

DIAGNOSTICS = {
    "AX_EMAFast", "AX_EMAMedium", "AX_EMASlow", "AX_FusionSlow", "AX_FusionFast", "AX_VWAP", "AX_RawFusion",
    "AX_RSI", "AX_RsiEMA", "AX_MACD", "AX_MACDSignal", "AX_MACDHist", "AX_StochK", "AX_StochD",
    "AX_FastWPR", "AX_SlowWPR", "AX_TurtleWPR", "AX_BuyConfidence", "AX_SellConfidence",
    "AX_TrendBull", "AX_TrendBear", "AX_LongEntry", "AX_ShortEntry", "AX_LongExit", "AX_ShortExit", "AX_Trend",
    "AX_ATR", "AX_BullScore", "AX_BearScore", "AX_Condition", "AX_HasEntry", "AX_EMA50", "AX_EMA200", "AX_VolumeStrength",
}


def timestamp(value):
    try:
        number = float(value)
        return round(number / 1000 if abs(number) > 1e11 else number)
    except ValueError:
        date = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        if date.tzinfo is None:
            raise ValueError("ISO timestamps must contain a UTC offset; export time as UNIX seconds instead")
        return round(date.timestamp())


def read_csv(path):
    rows = {}
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        headers = reader.fieldnames or []
        times = [h for h in headers if h.lower() == "time"]
        if len(times) != 1:
            raise ValueError(f"{path}: expected one 'time' column")
        aliases = {}
        for header in headers:
            key = header[header.index("AX_"):] if "AX_" in header else header.lower()
            if key in aliases:
                raise ValueError(f"{path}: ambiguous duplicate column {key}; export just one diagnostic indicator")
            aliases[key] = header
        for row in reader:
            key = timestamp(row[times[0]])
            if key in rows:
                raise ValueError(f"{path}: duplicate timestamp {key}")
            values = {}
            for alias, header in aliases.items():
                if alias == "time":
                    continue
                raw = row.get(header, "").strip()
                try:
                    value = float(raw)
                except ValueError:
                    value = math.nan
                values[alias] = value if math.isfinite(value) and abs(value) < 1e300 else math.nan
            rows[key] = values
    return rows, set(aliases)


def compare(tv_path, mt_path, after=None, atol=1e-7, rtol=1e-10):
    tv, tv_columns = read_csv(tv_path)
    mt, mt_columns = read_csv(mt_path)
    columns = sorted(c for c in mt_columns if c.startswith("AX_"))
    required = DIAGNOSTICS | {"open", "high", "low", "close", "volume"}
    missing = sorted((required - tv_columns) | (required - mt_columns))
    times = sorted(set(tv) & set(mt))
    if after is not None:
        times = [t for t in times if t >= after]
    mismatches = []
    failures = 0
    exact = {"AX_TrendBull", "AX_TrendBear", "AX_LongEntry", "AX_ShortEntry", "AX_LongExit", "AX_ShortExit",
             "AX_Trend", "AX_HasEntry", "AX_BullScore", "AX_BearScore", "AX_Condition"}
    max_error = {}
    input_differences = 0
    for time in times:
        for column in ["open", "high", "low", "close", "volume"] + columns:
            if column not in tv_columns or column not in mt_columns:
                continue
            a, b = tv[time][column], mt[time][column]
            both_missing = math.isnan(a) and math.isnan(b)
            matches = both_missing or (a == b if column in exact else math.isclose(a, b, rel_tol=rtol, abs_tol=atol))
            if math.isfinite(a) and math.isfinite(b):
                max_error[column] = max(max_error.get(column, 0), abs(a - b))
            if not matches:
                failures += 1
                input_differences += int(not column.startswith("AX_"))
                if len(mismatches) < 25:
                    mismatches.append({"time": time, "column": column,
                                       "tradingview": a if math.isfinite(a) else None,
                                       "mt5": b if math.isfinite(b) else None})
    return {"passed": bool(times) and not missing and failures == 0,
            "matched_bars": len(times), "diagnostic_columns": len(columns), "missing_columns": missing,
            "mismatched_values": failures, "input_data_mismatches": input_differences,
            "tv_only_bars": len(set(tv) - set(mt)), "mt5_only_bars": len(set(mt) - set(tv)),
            "compared_from_utc": dt.datetime.fromtimestamp(times[0], dt.timezone.utc).isoformat() if times else None,
            "compared_to_utc": dt.datetime.fromtimestamp(times[-1], dt.timezone.utc).isoformat() if times else None,
            "max_absolute_error": max_error, "first_mismatches": mismatches,
            "note": "Unmatched timestamps are reported separately. A pass applies only to the overlapping range and selected tolerances."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tradingview")
    parser.add_argument("mt5")
    parser.add_argument("--after", type=int, help="Compare from this UNIX UTC timestamp (optional warm-up cutoff)")
    parser.add_argument("--report", default="comparison.json")
    args = parser.parse_args()
    result = compare(args.tradingview, args.mt5, args.after)
    Path(args.report).write_text(json.dumps(result, indent=2, allow_nan=False), encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key not in {"max_absolute_error", "first_mismatches"}}, indent=2))
    raise SystemExit(0 if result["passed"] else 1)
