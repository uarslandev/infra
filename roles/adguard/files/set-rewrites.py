#!/usr/bin/env python3
"""Make AdGuard Home's DNS rewrites exactly match the list given as JSON (argv[1]).

Prints "unchanged" or "changed". Only on change: stop AdGuard, write the config, start it again.
Everything else in AdGuardHome.yaml (managed in the web UI) is left as is.
"""
import json
import subprocess
import sys

import yaml

CONFIG = "/opt/AdGuardHome/AdGuardHome.yaml"
desired = json.loads(sys.argv[1])

with open(CONFIG, encoding="utf-8") as f:
    config = yaml.safe_load(f)

filtering = config.setdefault("filtering", {})
current = filtering.get("rewrites") or []
uses_enabled = any("enabled" in r for r in current) or not current

wanted = []
for r in desired:
    entry = {"domain": r["domain"], "answer": r["answer"]}
    if uses_enabled:
        entry["enabled"] = True
    wanted.append(entry)

def key(rs):
    return sorted((r["domain"], r["answer"], r.get("enabled", True)) for r in rs)

if key(current) == key(wanted):
    print("unchanged")
    sys.exit(0)

filtering["rewrites"] = wanted
subprocess.run(["systemctl", "stop", "AdGuardHome"], check=True)
with open(CONFIG, "w", encoding="utf-8") as f:
    yaml.safe_dump(config, f, sort_keys=False, allow_unicode=True)
subprocess.run(["systemctl", "start", "AdGuardHome"], check=True)
print("changed")
