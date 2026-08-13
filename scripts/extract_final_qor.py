#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def parse_args():
    p = argparse.ArgumentParser(
        description="Extract normalized QoR from an OpenLane 2 final run."
    )
    p.add_argument("--run", required=True, type=Path)
    p.add_argument("--label", required=True)
    p.add_argument("--out-dir", type=Path, default=Path("reports/qor"))
    p.add_argument(
        "--signoff-summary",
        type=Path,
        default=Path("reports/signoff/final_signoff_summary.txt"),
    )
    return p.parse_args()


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def numeric(value: Any):
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)

    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None

    return None


def pick(metrics: dict[str, Any], aliases: list[str]):
    # Exact-name pass.
    for alias in aliases:
        if alias in metrics:
            return metrics[alias], alias

    # Normalized-name pass for older naming variants.
    normalized = {
        re.sub(r"[^a-z0-9]+", "_", k.lower()).strip("_"): k
        for k in metrics
    }

    for alias in aliases:
        n = re.sub(r"[^a-z0-9]+", "_", alias.lower()).strip("_")
        if n in normalized:
            key = normalized[n]
            return metrics[key], key

    return None, None


def first_numeric(metrics, aliases):
    value, source = pick(metrics, aliases)
    return numeric(value), source


def corner_metrics(metrics: dict[str, Any], mode: str):
    result = {}

    for key, value in metrics.items():
        lk = key.lower()

        if mode not in lk:
            continue

        if not any(token in lk for token in ("wns", "__ws", "slack")):
            continue

        number = numeric(value)
        if number is None:
            continue

        match = re.search(r"corner:([^,\s]+)", key, re.IGNORECASE)

        if match:
            corner = match.group(1)
        else:
            # Other OpenLane naming variants can put corner elsewhere.
            match = re.search(
                r"(max|nom|min)_(ff|ss|tt)_[a-z0-9_]+",
                key,
                re.IGNORECASE,
            )
            if not match:
                continue
            corner = match.group(0)

        # A corner can appear under multiple synonymous metrics.
        # Prefer the smallest slack conservatively.
        if corner not in result or number < result[corner]["wns_ns"]:
            result[corner] = {
                "wns_ns": number,
                "source_metric": key,
            }

    return dict(sorted(result.items()))


def electrical_metrics(metrics, kind: str):
    rows = []

    for key, value in metrics.items():
        lk = key.lower()

        if kind not in lk:
            continue

        if "count" not in lk and "violation" not in lk:
            continue

        number = numeric(value)
        if number is None:
            continue

        rows.append({
            "metric": key,
            "value": number,
        })

    return sorted(rows, key=lambda x: x["metric"])


def matched_raw_metrics(metrics):
    tokens = (
        "setup", "hold",
        "instance", "area", "util",
        "slew", "cap", "fanout",
        "wire", "route",
        "drc", "antenna", "lvs",
        "power", "clock", "skew",
    )

    return {
        k: metrics[k]
        for k in sorted(metrics)
        if any(token in k.lower() for token in tokens)
    }


def parse_signoff_summary(path: Path):
    result = {}

    if not path.is_file():
        return result

    text = path.read_text(encoding="utf-8", errors="replace")

    patterns = {
        "signoff_setup_wns_ns":
            r"Worst setup WNS\s*:\s*([+-]?[0-9.]+)",
        "signoff_hold_wns_ns":
            r"Worst hold WNS\s*:\s*([+-]?[0-9.]+)",
        "signoff_setup_view":
            r"Worst setup view\s*:\s*(\S+)",
        "signoff_hold_view":
            r"Worst hold view\s*:\s*(\S+)",
        "antenna_status":
            r"Antenna\s*:\s*(\S+)",
        "lvs_status":
            r"LVS\s*:\s*(\S+)",
        "drc_status":
            r"DRC\s*:\s*(\S+)",
    }

    for name, pattern in patterns.items():
        m = re.search(pattern, text)
        if not m:
            continue

        value = m.group(1)

        if name.endswith("_ns"):
            value = float(value)

        result[name] = value

    return result


def resolved_clock_period(resolved: dict[str, Any]):
    candidates = (
        "CLOCK_PERIOD",
        "clock_period",
    )

    for key in candidates:
        if key in resolved:
            return numeric(resolved[key]), key

    # Some resolved configurations may store values below config.
    config = resolved.get("config")
    if isinstance(config, dict):
        for key in candidates:
            if key in config:
                return numeric(config[key]), f"config.{key}"

    return None, None


def main():
    args = parse_args()

    run = args.run.resolve()
    metrics_file = run / "final" / "metrics.json"
    resolved_file = run / "resolved.json"

    if not run.is_dir():
        raise SystemExit(f"ERROR: run directory not found: {run}")

    if not metrics_file.is_file():
        raise SystemExit(
            f"ERROR: OpenLane final metrics not found: {metrics_file}"
        )

    if not resolved_file.is_file():
        raise SystemExit(
            f"ERROR: resolved configuration not found: {resolved_file}"
        )

    metrics = json.loads(metrics_file.read_text(encoding="utf-8"))
    resolved = json.loads(resolved_file.read_text(encoding="utf-8"))

    if not isinstance(metrics, dict):
        raise SystemExit("ERROR: final/metrics.json is not a JSON object")

    clock_period, clock_source = resolved_clock_period(resolved)

    instance_count, instance_count_src = first_numeric(metrics, [
        "design__instance__count",
        "design_instance_count",
    ])

    cell_area, cell_area_src = first_numeric(metrics, [
        "design__instance__area",
        "design_instance_area",
    ])

    core_area, core_area_src = first_numeric(metrics, [
        "design__core__area",
        "design_core_area",
    ])

    utilization, utilization_src = first_numeric(metrics, [
        "design__utilization",
        "design_utilization",
    ])

    setup = corner_metrics(metrics, "setup")
    hold = corner_metrics(metrics, "hold")

    worst_setup = (
        min(
            (
                (v["wns_ns"], corner, v["source_metric"])
                for corner, v in setup.items()
            ),
            default=None,
        )
    )

    worst_hold = (
        min(
            (
                (v["wns_ns"], corner, v["source_metric"])
                for corner, v in hold.items()
            ),
            default=None,
        )
    )

    signoff = parse_signoff_summary(args.signoff_summary)

    normalized = {
        "schema_version": 1,
        "label": args.label,
        "design": "rv32i_core",
        "run_name": run.name,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "sources": {
            "metrics_json": str(metrics_file),
            "metrics_json_sha256": sha256(metrics_file),
            "resolved_json": str(resolved_file),
            "resolved_json_sha256": sha256(resolved_file),
            "signoff_summary": (
                str(args.signoff_summary)
                if args.signoff_summary.is_file()
                else None
            ),
        },
        "clock": {
            "period_ns": clock_period,
            "frequency_mhz": (
                1000.0 / clock_period
                if clock_period and clock_period > 0
                else None
            ),
            "source_metric": clock_source,
        },
        "physical": {
            "standard_cell_instance_count": instance_count,
            "total_cell_area_um2": cell_area,
            "core_area_um2": core_area,
            "core_area_mm2": (
                core_area / 1_000_000.0
                if core_area is not None
                else None
            ),
            "utilization_pct": utilization,
            "sources": {
                "instance_count": instance_count_src,
                "cell_area": cell_area_src,
                "core_area": core_area_src,
                "utilization": utilization_src,
            },
        },
        "timing": {
            "setup_by_corner": setup,
            "hold_by_corner": hold,
            "worst_setup_wns_ns": (
                worst_setup[0] if worst_setup else None
            ),
            "worst_setup_corner": (
                worst_setup[1] if worst_setup else None
            ),
            "worst_hold_wns_ns": (
                worst_hold[0] if worst_hold else None
            ),
            "worst_hold_corner": (
                worst_hold[1] if worst_hold else None
            ),
        },
        "electrical": {
            # Do NOT convert absence of a metric to zero.
            "max_slew_metrics": electrical_metrics(metrics, "slew"),
            "max_capacitance_metrics": electrical_metrics(metrics, "cap"),
            "max_fanout_metrics": electrical_metrics(metrics, "fanout"),
        },
        "signoff_reference": signoff,
        "raw_selected_metrics": matched_raw_metrics(metrics),
    }

    args.out_dir.mkdir(parents=True, exist_ok=True)

    json_path = args.out_dir / f"{args.label}.json"
    csv_path = args.out_dir / f"{args.label}.csv"
    md_path = args.out_dir / f"{args.label}.md"

    json_path.write_text(
        json.dumps(normalized, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    # Long-form CSV is intentionally simple and stable for later
    # baseline-vs-experiment comparisons.
    rows = []

    def add(metric, value, unit="", source=""):
        rows.append({
            "metric": metric,
            "value": "" if value is None else value,
            "unit": unit,
            "source": source or "",
        })

    add("clock_period", clock_period, "ns", clock_source)
    add(
        "target_frequency",
        normalized["clock"]["frequency_mhz"],
        "MHz",
        clock_source,
    )

    add(
        "standard_cell_instance_count",
        instance_count,
        "count",
        instance_count_src,
    )
    add("total_cell_area", cell_area, "um^2", cell_area_src)
    add("core_area", core_area, "um^2", core_area_src)
    add(
        "core_area",
        normalized["physical"]["core_area_mm2"],
        "mm^2",
        core_area_src,
    )
    add("utilization", utilization, "%", utilization_src)

    for corner, data in setup.items():
        add(
            f"setup_wns[{corner}]",
            data["wns_ns"],
            "ns",
            data["source_metric"],
        )

    for corner, data in hold.items():
        add(
            f"hold_wns[{corner}]",
            data["wns_ns"],
            "ns",
            data["source_metric"],
        )

    add(
        "worst_setup_wns",
        normalized["timing"]["worst_setup_wns_ns"],
        "ns",
        normalized["timing"]["worst_setup_corner"],
    )
    add(
        "worst_hold_wns",
        normalized["timing"]["worst_hold_wns_ns"],
        "ns",
        normalized["timing"]["worst_hold_corner"],
    )

    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=("metric", "value", "unit", "source"),
        )
        writer.writeheader()
        writer.writerows(rows)

    def fmt(value, digits=6):
        if value is None:
            return "N/A"
        if isinstance(value, float):
            return f"{value:.{digits}f}"
        return str(value)

    md = []
    md.append(f"# QoR Baseline — {args.label}")
    md.append("")
    md.append(f"- Design: `rv32i_core`")
    md.append(f"- Run: `{run.name}`")
    md.append(f"- Metrics source: `{metrics_file}`")
    md.append(
        f"- Metrics SHA-256: `{normalized['sources']['metrics_json_sha256']}`"
    )
    md.append("")

    md.append("## Clock and Physical QoR")
    md.append("")
    md.append("| Metric | Value |")
    md.append("|---|---:|")
    md.append(
        f"| Clock period | {fmt(clock_period, 3)} ns |"
    )
    md.append(
        f"| Target frequency | "
        f"{fmt(normalized['clock']['frequency_mhz'], 3)} MHz |"
    )
    md.append(
        f"| Standard-cell instances | "
        f"{fmt(instance_count, 0)} |"
    )
    md.append(
        f"| Total cell area | {fmt(cell_area, 3)} µm² |"
    )
    md.append(
        f"| Core area | "
        f"{fmt(normalized['physical']['core_area_mm2'], 6)} mm² |"
    )
    md.append(
        f"| Utilization | {fmt(utilization, 4)}% |"
    )
    md.append("")

    md.append("## MCMM Timing")
    md.append("")
    md.append("| Corner | Setup WNS (ns) | Hold WNS (ns) |")
    md.append("|---|---:|---:|")

    corners = sorted(set(setup) | set(hold))

    for corner in corners:
        s = setup.get(corner, {}).get("wns_ns")
        h = hold.get(corner, {}).get("wns_ns")
        md.append(
            f"| `{corner}` | {fmt(s)} | {fmt(h)} |"
        )

    md.append("")
    md.append(
        f"- Worst setup WNS: "
        f"**{fmt(normalized['timing']['worst_setup_wns_ns'])} ns**"
        f" @ `{normalized['timing']['worst_setup_corner']}`"
    )
    md.append(
        f"- Worst hold WNS: "
        f"**{fmt(normalized['timing']['worst_hold_wns_ns'])} ns**"
        f" @ `{normalized['timing']['worst_hold_corner']}`"
    )
    md.append("")

    md.append("## Electrical Metrics")
    md.append("")
    md.append(
        "Electrical violations are reported only when present in the "
        "OpenLane metrics. Missing metrics are **not interpreted as zero**."
    )
    md.append("")

    for title, field in (
        ("Max slew", "max_slew_metrics"),
        ("Max capacitance", "max_capacitance_metrics"),
        ("Max fanout", "max_fanout_metrics"),
    ):
        md.append(f"### {title}")
        md.append("")
        entries = normalized["electrical"][field]

        if not entries:
            md.append("No matching metric found.")
        else:
            md.append("| Metric | Value |")
            md.append("|---|---:|")
            for item in entries:
                md.append(
                    f"| `{item['metric']}` | {item['value']} |"
                )
        md.append("")

    md.append("## Signoff Reference")
    md.append("")

    if signoff:
        md.append("```text")
        for key, value in sorted(signoff.items()):
            md.append(f"{key}: {value}")
        md.append("```")
    else:
        md.append("No committed signoff summary was parsed.")

    md.append("")
    md.append(
        "> Power values, when present in raw OpenLane metrics, are "
        "tool-reported estimates and are not treated as silicon measurements."
    )
    md.append("")

    md_path.write_text("\n".join(md), encoding="utf-8")

    print("QoR extraction: PASS")
    print(f"Run       : {run}")
    print(f"Metrics   : {metrics_file}")
    print(f"JSON      : {json_path}")
    print(f"CSV       : {csv_path}")
    print(f"Markdown  : {md_path}")
    print(
        "Setup WNS : "
        f"{normalized['timing']['worst_setup_wns_ns']} "
        f"@ {normalized['timing']['worst_setup_corner']}"
    )
    print(
        "Hold WNS  : "
        f"{normalized['timing']['worst_hold_wns_ns']} "
        f"@ {normalized['timing']['worst_hold_corner']}"
    )


if __name__ == "__main__":
    main()
