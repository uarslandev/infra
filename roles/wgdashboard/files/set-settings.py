#!/usr/bin/env python3
"""Make the given WGDashboard settings true in wg-dashboard.ini (argv[1]), leaving the rest as is.

stdin: JSON {"settings": {section: {key: value}}, "password": "<admin password>"}. The password is
stored as a bcrypt hash, as WGDashboard stores it, and replaced only when the stored hash doesn't
match it. Prints "unchanged" or "changed". Only on change: stop the dashboard if it runs, write the
file (root, 0600), start it again; a running dashboard would otherwise write its own copy back.
Run it with WGDashboard's own Python (its venv has bcrypt).
"""
import configparser
import json
import os
import subprocess
import sys

import bcrypt

SERVICE = "wg-dashboard"
path = sys.argv[1]
wanted = json.load(sys.stdin)

# The same parser WGDashboard uses, so the file reads back exactly as it wrote it.
config = configparser.RawConfigParser(strict=False)
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        config.read_file(f)

changed = False
for section, keys in wanted["settings"].items():
    if not config.has_section(section):
        config.add_section(section)
    for key, value in keys.items():
        if config.get(section, key, fallback=None) != value:
            config.set(section, key, value)
            changed = True

password = wanted["password"].encode("utf-8")
stored = config.get("Account", "password", fallback="")
if not (stored.startswith("$2") and bcrypt.checkpw(password, stored.encode("utf-8"))):
    config.set("Account", "password", bcrypt.hashpw(password, bcrypt.gensalt()).decode("utf-8"))
    changed = True

if not changed:
    print("unchanged")
    sys.exit(0)

running = subprocess.run(["systemctl", "is-active", "--quiet", SERVICE], check=False).returncode == 0
if running:
    subprocess.run(["systemctl", "stop", SERVICE], check=True)
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w", encoding="utf-8") as f:
    config.write(f)
if running:
    subprocess.run(["systemctl", "start", SERVICE], check=True)
print("changed")
