# RC10 v0.8 setup and test

Required:
- Foundry
- Solidity 0.8.36
- `forge-std` available under `lib/forge-std`

`foundry.toml` locks optimizer = true, runs = 200, EVM = Cancun, fuzz = 10,000 and invariant runs = 1,000.

The release-gate helper `evidence/run_v08_release_gate.sh` first checks the final v0.8 source SHA-256, runs the deterministic model and stress checks, then runs a clean build, size report and full test suite. The supplied gate-green package includes the resulting fresh EVM evidence under `evidence/fresh_v08_evm/`. The helper intentionally refuses to continue if Foundry or forge-std is missing.

Expected current suite size: **72 Solidity test functions**.

Available local checks (no blockchain connection required):

```bash
python3 evidence/validate_rc10_v08.py
python3 evidence/simulate_v08_behavior.py
python3 evidence/stress_v08_curve.py
```

The stress model mirrors the Solidity fixed-point curve and cumulative-cost arithmetic, including endpoint, monotonicity, range, telescoping and quote-boundary cases. It is useful preflight evidence, but it is not a substitute for compiling and executing the Solidity on an EVM.

Do not reuse the archived RC10 v0.6 67/67 result as v0.8 EVM proof. Review the supplied v0.8 EVM evidence before deployment; an independent local rerun remains recommended when Foundry is available.
