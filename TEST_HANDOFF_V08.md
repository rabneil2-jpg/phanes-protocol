# RC10 v0.8 test handoff

## What has been run in this workspace

- Static/source/economic wiring: **62/62 PASS**.
- Executed behaviour/economic model: **37/37 PASS**, including 100,000 randomized invariant cases.
- Fixed-point curve stress model: **600,000 randomized cases PASS** — 250,000 sorted monotonic/range cases, 250,000 telescoping-cost triplets and 100,000 affordable-quote boundary cases.
- Website checks: inline JavaScript syntax, required metadata, reduced-motion fallback, no external script dependency, no wallet/purchase flow, and Netlify publish configuration: **PASS**.
- Solidity test definitions present: **72**. These have not been compiled in this workspace.

The model checks mirror the contract constants and integer arithmetic, including the exact $0.12 terminal quote and the exact full-sale cumulative model of 860,823,333,333 micro-USDC. They are preflight evidence only.

## Required fresh Foundry/EVM run

Run from this package root in an environment with Foundry, Solidity 0.8.36 and `lib/forge-std` available:

```bash
forge --version
forge clean
forge build --sizes
forge test -vvv
forge test --fuzz-runs 100000 --invariant-runs 5000 -vvv
```

Record the raw output and tool versions under `evidence/fresh_v08_evm/`. The release-gate helper performs the source-hash check and invokes the static, behaviour, stress and EVM stages:

```bash
bash evidence/run_v08_release_gate.sh
```

The helper intentionally stops if Forge or `lib/forge-std` is missing. Do not treat the old RC10 v0.6 `67/67` result as v0.8 EVM proof. Do not deploy to Sepolia or mainnet until the fresh v0.8 compilation/tests, bytecode-size record, deployment addresses and final release-manifest fingerprint have been reviewed.
