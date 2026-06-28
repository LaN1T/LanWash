#!/usr/bin/env python3
"""Generate nginx/.htpasswd for Prometheus/Metrics basic auth.

Reads PROMETHEUS_USER and PROMETHEUS_PASSWORD from the environment and writes
an nginx-compatible htpasswd file using the APR1-MD5 algorithm (openssl).
Run before deploying:

    PROMETHEUS_USER=admin PROMETHEUS_PASSWORD='secret' python3 scripts/generate_nginx_htpasswd.py

The generated file is gitignored and must not be committed.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> None:
    user = os.getenv("PROMETHEUS_USER")
    password = os.getenv("PROMETHEUS_PASSWORD")

    if not user or not password:
        raise SystemExit(
            "Set PROMETHEUS_USER and PROMETHEUS_PASSWORD environment variables."
        )

    htpasswd_path = Path(__file__).resolve().parent.parent / "nginx" / ".htpasswd"
    htpasswd_path.parent.mkdir(parents=True, exist_ok=True)

    # Docker may have created this path as a directory; replace it with a file.
    if htpasswd_path.is_dir():
        shutil.rmtree(htpasswd_path)

    try:
        hashed = subprocess.run(
            ["openssl", "passwd", "-apr1", password],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except FileNotFoundError:
        raise SystemExit("openssl is required to generate the htpasswd file.")
    except subprocess.CalledProcessError as exc:
        raise SystemExit(f"openssl failed: {exc.stderr or exc.stdout}")

    htpasswd_path.write_text(f"{user}:{hashed}\n", encoding="utf-8")
    print(f"Generated {htpasswd_path}")


if __name__ == "__main__":
    main()
