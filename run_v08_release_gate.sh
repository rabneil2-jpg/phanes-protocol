#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
EXPECTED="70e342e76d553400ffc093c9dba69eda5ff6ad2fe6dc5828c1bd728ba53289be"
ACTUAL="$(sha256sum src/PHANES_RC10_v0_8.sol | awk '{print $1}')"
[ "$ACTUAL" = "$EXPECTED" ] || { echo "SOURCE HASH MISMATCH: $ACTUAL"; exit 1; }
python3 evidence/validate_rc10_v08.py | tee evidence/fresh_v08_static.txt
python3 evidence/simulate_v08_behavior.py | tee evidence/fresh_v08_model.txt
python3 evidence/stress_v08_curve.py | tee evidence/fresh_v08_stress.txt
command -v forge >/dev/null || { echo "forge not found"; exit 2; }
[ -f lib/forge-std/src/Test.sol ] || { echo "forge-std missing: install/vendor foundry-rs/forge-std before running tests"; exit 3; }
mkdir -p evidence/fresh_v08_evm
forge --version | tee evidence/fresh_v08_evm/FOUNDRY_VERSION.txt
forge clean
forge build --sizes 2>&1 | tee evidence/fresh_v08_evm/FORGE_BUILD_SIZES.txt
forge test -vvv 2>&1 | tee evidence/fresh_v08_evm/FORGE_TEST_V08.txt
printf '%s  %s\n' "$ACTUAL" src/PHANES_RC10_v0_8.sol > evidence/fresh_v08_evm/SOURCE_SHA256.txt
echo "RC10 v0.8 release gate complete"
