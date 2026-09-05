# RC10 v0.8 test status — 5 September 2026 (fresh gate)

## Current candidate
- Source: `src/PHANES_RC10_v0_8.sol`
- Source SHA-256: `70e342e76d553400ffc093c9dba69eda5ff6ad2fe6dc5828c1bd728ba53289be`
- Constitution SHA-256: `6c5f96f410cc3c84cf1e9dec8016de7e8c8efe59396e45db25c962c08b20808f`
- Solidity target: **0.8.36**
- Optimizer: **enabled / 200 runs**
- EVM target: **Cancun**

## Fresh gate results (this package)

| Check | Result |
|-------|--------|
| Static / source / economic wiring | **62 / 62 PASS** |
| Behaviour / economic model | **37 / 37 PASS** (+ 100 000 randomized invariant cases) |
| Curve stress (monotonic + telescoping + affordable-quote) | **PASS** (600 000 cases) |
| Solidity / Foundry unit + fuzz tests | **72 / 72 PASS** |
| PHANES runtime size | **14 681 B** (margin 9 895 B under 24 576 B EIP-170 limit) |
| Foundry version | forge 1.8.1 (982849d314 · 2026-08-28) |

Raw logs are in:
- `evidence/fresh_v08_static.txt`
- `evidence/fresh_v08_model.txt`
- `evidence/fresh_v08_stress.txt`
- `evidence/fresh_v08_evm/FORGE_TEST_V08.txt`
- `evidence/fresh_v08_evm/FORGE_BUILD_SIZES.txt`
- `evidence/fresh_v08_evm/FOUNDRY_VERSION.txt`
- `evidence/fresh_v08_evm/SOURCE_SHA256.txt`

## One test-file fix only (source untouched)

`test/PHANES_RC10_TradingAfterKhaos.t.sol` contained the classic Foundry footgun:

```solidity
vm.prank(buyer); phn.transfer(recipient, phn.balanceOf(buyer) / 2);
```

The nested `balanceOf` consumed the prank, so the transfer executed from the test contract. The amount is now snapshotted first. **The production Solidity source hash is identical to the previous handoff.**

## Status

The release gate is green. Deployment of the guarded mainnet wrapper is now the next founder action. See `DEPLOY_MAINNET.md`.
