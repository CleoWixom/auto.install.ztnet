#!/usr/bin/env bash
set -euo pipefail

SCRIPT="ztnet.sh"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

pass() {
  echo "[PASS] $*"
}

require_pattern() {
  local pattern="$1"
  local message="$2"
  if ! grep -qE "$pattern" "$SCRIPT"; then
    fail "$message"
  fi
  pass "$message"
}

# 1) Script syntax is valid.
bash -n "$SCRIPT" || fail "bash syntax check failed"
pass "bash syntax check"

# 2) Appended section starts after final ZTnet URL echo.
line_echo=$(grep -n 'ZTnet is waiting for you at:' "$SCRIPT" | tail -1 | cut -d: -f1)
line_cd=$(grep -n '^cd /root || cd /$' "$SCRIPT" | tail -1 | cut -d: -f1)

[ -n "${line_echo:-}" ] || fail "final ZTnet URL echo line not found"
[ -n "${line_cd:-}" ] || fail "appended section start (cd /root || cd /) not found"

if [ "$line_cd" -le "$line_echo" ]; then
  fail "appended section must start after final ZTnet URL echo"
fi
pass "appended section starts after final echo"

# 3) All required functions are present.
required_functions=(
  exitnode_patch_zerotier
  exitnode_wait_ztnet
  exitnode_create_admin
  exitnode_create_network
  exitnode_configure_network
  exitnode_join_network
  exitnode_authorize
  exitnode_setup_unbound
  exitnode_install_zt2unbound
  exitnode_setup_firewall
  exitnode_print_summary
)

for fn in "${required_functions[@]}"; do
  require_pattern "^${fn}\(\) \{" "function ${fn} is defined"
done

# 4) Main call order appears in correct sequence.
last_line=0
for fn in "${required_functions[@]}"; do
  line=$(grep -n "^${fn}$" "$SCRIPT" | tail -1 | cut -d: -f1)
  [ -n "${line:-}" ] || fail "main call '${fn}' not found"
  if [ "$line" -le "$last_line" ]; then
    fail "main call order is incorrect at '${fn}'"
  fi
  last_line="$line"
done
pass "main call order is correct"

# 5) Guard against accidental redefinition of restricted helper functions.
restricted=(
  command_exists
  ask_question
  ask_string
  silent
  verbose
  set_env_target_var
  cleanup
  failure
  is_package_installed
)

for fn in "${restricted[@]}"; do
  count=$(grep -Ec "^(function[[:space:]]+)?${fn}\(\)" "$SCRIPT" || true)
  if [ "$count" -ne 1 ]; then
    fail "expected exactly one definition of restricted function '${fn}', found ${count}"
  fi
done
pass "restricted helper functions are not redefined"

echo "All ExitNode installer tests passed."
