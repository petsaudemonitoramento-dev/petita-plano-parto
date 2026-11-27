"""POSIX process-group timeout fallback for Cloud runners without GNU timeout."""
import os
import signal
import subprocess
import sys
seconds=int(sys.argv[1])
if not 1<=seconds<=1200 or len(sys.argv)<3:raise SystemExit(2)
process=subprocess.Popen(sys.argv[2:],start_new_session=True)
try:
    status=process.wait(timeout=seconds)
except subprocess.TimeoutExpired:
    os.killpg(process.pid,signal.SIGTERM)
    try:process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=5)
    try:os.killpg(process.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    status=124
raise SystemExit(status if status>=0 else 128-status)
