#!/usr/bin/env python3
"""Run the ARQ worker process."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from arq import run_worker

from tasks import WorkerSettings

if __name__ == "__main__":
    run_worker(WorkerSettings)
