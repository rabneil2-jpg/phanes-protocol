# RC10 v0.8 test status — 5 September 2026

## Current candidate
- Source: `src/PHANES_RC10_v0_8.sol`
- Source SHA-256: `70e342e76d553400ffc093c9dba69eda5ff6ad2fe6dc5828c1bd728ba53289be`
- Constitution SHA-256: `6c5f96f410cc3c84cf1e9dec8016de7e8c8efe59396e45db25c962c08b20808f`
- Solidity target: **0.8.36**
- Optimizer: **enabled / 200 runs**
- EVM target: **Cancun**

## Completed in this environment
- **62/62** static/source/economic wiring checks PASS.
- **37/37** executed behaviour/economic model checks PASS.
- **100,000** randomized invariant cases PASS.
- **72** Solidity/Foundry test functions are present and wired to the v0.8 source.
- Curve stress model: **600,000** deterministic randomized cases PASS across monotonic/range, telescoping-cost and affordable-quote checks.
- New regression coverage includes: exact 48-hour KHAOS transfer gate, permanent transferability after the gate, later-epoch immediate transferability, no early public-finalization side effect, founder gate alignment, no old 150k cap, and separation of holder transfers from the 2m protocol-liquidity allocation.

## Historical baseline only
RC10 v0.6 previously returned **67/67 Foundry PASS** before the transferability redesign. That is useful regression history but is **not** v0.8 EVM proof.

## Mandatory next proof
Fresh Forge/Solidity EVM execution has **not** been run for v0.8 in this container because Forge/solc 0.8.36 is unavailable here and the runtime cannot fetch compiler binaries.

Before Base Sepolia or mainnet:
1. `forge clean && forge build`
2. `forge test -vvv`
3. confirm all 72 tests pass
4. run the configured fuzz/invariant suite
5. record bytecode/initcode sizes
6. save raw output and tool versions into `evidence/`

No v0.8 deployment is authorised merely by the model/static results.
