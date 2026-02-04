#!/bin/bash
set -euo pipefail

# Ensure micromamba is initialized + env auto-activated
if [ -f /root/.bashrc ]; then
  set +u
  # shellcheck disable=SC1091
  source /root/.bashrc
  set -u
fi

ENV_NAME="${ENV_NAME:-py310}"

echo "[entrypoint] Using env: ${ENV_NAME}"
echo "[entrypoint] Workdir: $(pwd)"

# Editable install (NO deps) — required by policy
if [ -d "/workspace" ]; then
  cd /workspace
fi

if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  echo "[entrypoint] Installing current project editable (-e . --no-deps)"
  micromamba run -n "${ENV_NAME}" python -m pip install -e . --no-deps
else
  echo "[entrypoint] No pyproject.toml/setup.py found in /workspace; skipping editable install."
fi

# Optional extras install (matches your setup.md guidance, but off by default)
# Usage:
#   SAM3D_INSTALL_EXTRAS=1  (installs dev then p3d then inference if those extras exist)
if [ "${SAM3D_INSTALL_EXTRAS:-0}" = "1" ] && [ -f "pyproject.toml" ]; then
  echo "[entrypoint] SAM3D_INSTALL_EXTRAS=1 => installing extras (dev -> p3d -> inference)"
  micromamba run -n "${ENV_NAME}" python -m pip install -e '.[dev]' --no-deps
  micromamba run -n "${ENV_NAME}" python -m pip install -e '.[p3d]' --no-deps || {
    echo "[entrypoint] ERROR: failed to install extra [p3d]."; exit 1;
  }
  micromamba run -n "${ENV_NAME}" python -m pip install -e '.[inference]' --no-deps || {
    echo "[entrypoint] ERROR: failed to install extra [inference]."; exit 1;
  }
fi

# Optional patch step referenced by setup.md (use env python so 'python' is found)
if [ -x "./patching/hydra" ]; then
  echo "[entrypoint] Running patch: ./patching/hydra"
  micromamba run -n "${ENV_NAME}" python ./patching/hydra
fi

# Exec
if [ "$#" -gt 0 ]; then
  exec "$@"
else
  exec bash
fi
