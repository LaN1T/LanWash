#!/usr/bin/env python3
"""Generate nginx/.htpasswd for Prometheus/Metrics basic auth.

Reads PROMETHEUS_USER and PROMETHEUS_PASSWORD from the environment and writes
an nginx-compatible htpasswd file. Run before deploying:

    python scripts/generate_nginx_htpasswd.py

The generated file is gitignored and must not be committed.
"""

import os
from pathlib import Path

from passlib.apache import HtpasswdFile


def main() -> None:
    user = os.getenv("PROMETHEUS_USER")
    password = os.getenv("PROMETHEUS_PASSWORD")

    if not user or not password:
        raise SystemExit(
            "Set PROMETHEUS_USER and PROMETHEUS_PASSWORD environment variables."
        )

    htpasswd_path = Path(__file__).resolve().parent.parent / "nginx" / ".htpasswd"
    htpasswd_path.parent.mkdir(parents=True, exist_ok=True)

    ht = HtpasswdFile(str(htpasswd_path), new=True)
    ht.set_password(user, password)
    ht.save()

    print(f"Generated {htpasswd_path}")


if __name__ == "__main__":
    main()
