#!/usr/bin/env bash
set -euo pipefail

# Real (non-simulated) preflight for dedicated self-hosted runners.
# This test is intentionally destructive-gated and should only run on ephemeral hosts.

if [[ "${RUN_REAL_EXITNODE_TESTS:-0}" != "1" ]]; then
  echo "[SKIP] RUN_REAL_EXITNODE_TESTS!=1"
  exit 0
fi

if [[ "${ZTNET_REAL_TEST_ALLOW_DESTRUCTIVE:-NO}" != "YES" ]]; then
  echo "[FAIL] Set ZTNET_REAL_TEST_ALLOW_DESTRUCTIVE=YES to continue"
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "[FAIL] Real ExitNode test requires root"
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "[FAIL] systemctl not found; real test requires systemd host"
  exit 1
fi

if ! systemctl list-unit-files >/dev/null 2>&1; then
  echo "[FAIL] systemd is not active/usable on this runner"
  exit 1
fi

for bin in bash curl jq openssl ip; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "[FAIL] Missing required binary: $bin"
    exit 1
  fi
done

if [[ ! -f ztnet.sh ]]; then
  echo "[FAIL] ztnet.sh not found"
  exit 1
fi

bash -n ztnet.sh

echo "[PASS] Real preflight passed on self-hosted systemd runner."
echo "[INFO] This workflow is non-simulated and intended for dedicated ephemeral runners."
