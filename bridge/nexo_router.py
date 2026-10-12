#!/usr/bin/env python3
"""
NEXO Portal Fabric - campaign router v0.1

Consumes a neutral handoff whose target is NEXO_HUB and resolves the next
campaign adapter without hard-wiring DOOM directly to a third engine.

This stage is data-only: a planned route is not automatically launchable.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_HANDOFF = ROOT / "bridge" / "runtime" / "handoff_from_doom.json"
DEFAULT_CAMPAIGN = ROOT / "bridge" / "campaign.json"
DEFAULT_OUTPUT = ROOT / "bridge" / "runtime" / "route.json"


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(path)
    return json.loads(path.read_text(encoding="utf-8"))


def validate_handoff(data: dict[str, Any]) -> None:
    if data.get("schema") != "nexo.portal.handoff.v1":
        raise RuntimeError("Unsupported handoff schema")

    if data.get("target", {}).get("world") != "NEXO_HUB":
        raise RuntimeError(
            "Router only accepts handoffs addressed to NEXO_HUB; "
            f"got {data.get('target', {}).get('world')!r}"
        )

    for key in ("source", "target", "mission", "player_state", "cargo"):
        if key not in data:
            raise RuntimeError(f"Handoff missing required block: {key}")


def validate_campaign(data: dict[str, Any]) -> None:
    if data.get("schema") != "nexo.campaign.v1":
        raise RuntimeError("Unsupported campaign schema")
    if not isinstance(data.get("chapters"), list) or not data["chapters"]:
        raise RuntimeError("Campaign has no chapters")


def chapter_by_id(campaign: dict[str, Any], chapter_id: str) -> dict[str, Any]:
    for chapter in campaign["chapters"]:
        if chapter.get("id") == chapter_id:
            return chapter
    raise RuntimeError(f"Campaign chapter not found: {chapter_id}")


def resolve_route(
    handoff: dict[str, Any],
    campaign: dict[str, Any],
) -> dict[str, Any]:
    mission_id = str(handoff.get("mission", {}).get("id", ""))
    current = chapter_by_id(campaign, mission_id)

    hub_id = current.get("next")
    if not hub_id:
        raise RuntimeError(f"Chapter {mission_id} has no next route")

    hub = chapter_by_id(campaign, str(hub_id))
    if hub.get("world") != "NEXO_HUB":
        raise RuntimeError(
            f"Chapter {mission_id} routes to {hub.get('world')!r}, expected NEXO_HUB"
        )

    next_id = hub.get("next")
    if not next_id:
        raise RuntimeError("NEXO_HUB chapter has no next campaign chapter")

    destination = chapter_by_id(campaign, str(next_id))

    cargo = dict(handoff.get("cargo", {}))
    requirements = dict(destination.get("requires", {}))
    unmet: dict[str, dict[str, int]] = {}

    for key, minimum in requirements.items():
        actual = int(cargo.get(key, 0))
        if actual < int(minimum):
            unmet[key] = {"required": int(minimum), "actual": actual}

    destination_status = str(destination.get("status", "planned"))
    requirements_met = not unmet

    # Route resolution can succeed while execution remains intentionally gated.
    # A runtime adapter must be explicitly promoted to ready before launch.
    launch_allowed = requirements_met and destination_status == "ready"

    return {
        "schema": "nexo.portal.route.v1",
        "campaign_id": campaign.get("campaign_id", "UNKNOWN"),
        "source": {
            "handoff_target": handoff["target"]["world"],
            "completed_mission": mission_id,
            "completed_world": handoff["source"]["world"],
        },
        "route": {
            "hub_chapter": hub["id"],
            "next_chapter": destination["id"],
            "world": destination["world"],
            "adapter": destination["adapter"],
            "adapter_status": destination_status,
            "requirements_met": requirements_met,
            "launch_allowed": launch_allowed,
            "unmet_requirements": unmet,
        },
        "campaign_state": {
            "score": int(handoff.get("mission", {}).get("score", 0)),
            "logical_mass": float(
                handoff.get("player_state", {}).get("logical_mass", 0.0)
            ),
            "cargo": cargo,
            "identity": dict(handoff.get("identity", {})),
            "perspective": dict(handoff.get("perspective", {})),
            "derived": dict(handoff.get("derived", {})),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve NEXO_HUB campaign route")
    parser.add_argument("--handoff", type=Path, default=DEFAULT_HANDOFF)
    parser.add_argument("--campaign", type=Path, default=DEFAULT_CAMPAIGN)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--print", dest="print_json", action="store_true")
    args = parser.parse_args()

    handoff = load_json(args.handoff)
    campaign = load_json(args.campaign)
    validate_handoff(handoff)
    validate_campaign(campaign)

    route = resolve_route(handoff, campaign)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(route, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    r = route["route"]
    print(f"[NEXO] Hub route resolved: {r['next_chapter']} -> {r['world']}")
    print(f"[NEXO] Adapter: {r['adapter']} ({r['adapter_status']})")
    print(f"[NEXO] Requirements met: {r['requirements_met']}")
    print(f"[NEXO] Launch allowed: {r['launch_allowed']}")
    print(f"[NEXO] Route written: {args.output}")

    if args.print_json:
        print(json.dumps(route, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
