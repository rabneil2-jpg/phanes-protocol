# RC10 v0.8 pricing revision record — 5 September 2026

## Decision

RC10 v0.8 changes the mathematical terminal primary-issuance quote from the prior RC10 v0.7 candidate's $2.00 endpoint to **$0.12** at full acquisition of the **17,000,000 PHN** public allocation.

The revised curve is:

```text
P(x) = 0.01 + 0.023820x + 0.086180x²
x = cumulative public PHN acquired / 17,000,000
```

The integer Solidity constants are `PRICE_A = 10_000`, `PRICE_B = 23_820` and `PRICE_C = 86_180` micro-USDC per whole PHN. Their sum is exactly `120_000` micro-USDC, or $0.12.

The modelled cumulative cost at a complete public sellout is **860,823,333,333 micro-USDC** (approximately **$860,823.33**). This is a primary-issuance calculation only. It is not a forecast, market-price target, floor, promise, guarantee or DEX price protection. The curve does not reset between epochs and is not matched to secondary-market trading.

## Scope boundary

This revision changes the primary-issuance quote math and the related public documentation/tests. It does not change the fixed 21m supply, allocation amounts, epoch timestamps, 48-hour KHAOS transfer gate, permanent transferability after that gate, founder tranche schedule or separate protocol-liquidity vault.

The gate-green handoff includes fresh Solidity compilation, Forge/EVM tests and bytecode-size evidence under `evidence/fresh_v08_evm/`. Release-manifest approval remains a separate post-deployment requirement; the exact final fingerprint is calculated from the completed manifest containing the deployed mainnet graph.
