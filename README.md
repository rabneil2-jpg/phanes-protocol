# PHANES

## RC10 v0.8 — pre-mainnet production candidate

**Status:** Experimental · Not audited · Gate green · Ready for founder-signed Base Mainnet deployment · Not deployed · Not available for purchase

This repository describes the PHANES RC10 v0.8 candidate for Base. It is a source, test and informational-website handoff; it is not a deployment claim. RC10 v0.8 supersedes the prior RC10 v0.7 package only for the terminal primary-issuance curve. RC7, RC9 and older RC10 rules, addresses and launch claims are historical and unsupported.

PHANES uses the symbol **PHN** with **4 decimal places**.

## Fixed supply and allocations

Total supply is fixed at **21,000,000 PHN**:

| Allocation | Amount |
|---|---:|
| Public issuance | 17,000,000 PHN |
| Protocol liquidity | 2,000,000 PHN |
| Founder allocation | 1,000,000 PHN |
| Security and ecosystem rewards | 750,000 PHN |
| Launch Enablement | 250,000 PHN |

The public buyer cap is **none**. The public issuance price is one continuous global curve and does not reset between epochs.

## RC10 v0.8 pricing

The primary-issuance curve is:

```text
P(x) = 0.01 + 0.023820x + 0.086180x²
x = cumulative public PHN acquired / 17,000,000
```

Therefore:

- the initial quote is **$0.01**;
- the mathematical terminal primary-issuance quote is **$0.12 only at full acquisition of all 17,000,000 public PHN**;
- the modelled gross USDC committed at a complete public sellout is approximately **$860,823.33**.

The $0.12 terminal figure is an issuance calculation, not a market-price forecast, floor, promise, guarantee or target. The curve applies to primary issuance only. Secondary-market trading has independent price discovery after the transfer gate opens; the curve is not reset to, matched to or protected by a DEX price.

## Epoch sequence

**KHAOS → CHRONOS → ANANKE → AITHER → OION → THE FINAL SEAL → PHANES**

| Epoch | Opens | Public-issuance rule |
|---|---|---|
| KHAOS | 21 December 2026 · 20:50 UTC | 5,000,000 PHN; 20% is globally eligible immediately and the remaining 80% becomes eligible continuously over 48 hours |
| CHRONOS | 22 April 2027 · 20:50 UTC | 4,500,000 PHN |
| ANANKE | 23 August 2027 · 20:50 UTC | 4,000,000 PHN |
| AITHER | 22 December 2027 · 20:50 UTC | 3,500,000 PHN |
| OION | 22 April 2028 · 20:50 UTC | Unsold normal-epoch rollover; not an additional fixed allocation |

OION closes on **4 June 2028 · 06:59 UTC**. The Final Seal begins at that point. Symbolic PHANES emergence is **22 September 2028 · 20:50 UTC** and has no holder-unlock effect.

## Transferability

- KHAOS opens on **21 December 2026 at 20:50 UTC**.
- 1,000,000 PHN, or 20% of the KHAOS allocation, is globally eligible immediately; the remaining 4,000,000 PHN streams in over 48 hours.
- PHN transfers, approvals and `transferFrom` are locked only during those first 48 hours.
- At **23 December 2026 at 20:50 UTC**, full transferability and secondary-market compatibility become permanently available and never relock.
- KHAOS purchases cannot transfer during the initial window. CHRONOS, ANANKE, AITHER and OION purchases are immediately transferable on receipt.

There is no 2028 holder-unlock event and no 2030 holder-unlock event.

## Founder allocation

The **1,000,000 PHN** founder allocation releases progressively as five equal **200,000 PHN** tranches at KHAOS, CHRONOS, ANANKE, AITHER and OION. The Founder Vault has no early-withdrawal or acceleration path. The KHAOS tranche follows the shared 48-hour transfer gate; later tranches are immediately transferable after release.

There is no founder allocation held until 2030 and no post-2030 125,000-PHN vesting schedule.

## Protocol liquidity and rewards

The **2,000,000 PHN** protocol-liquidity allocation is separate from transferability and does not automatically enter a DEX at the transfer opening. This candidate does not implement a discretionary 2m PHN DEX dump; any official liquidity deployment requires a separately release-gated and audited adapter.

The **750,000 PHN** Security and Ecosystem Rewards pot is a controlled programme allocation, not a personal founder withdrawal balance. Technical claims require Reviewer One; non-technical claims above 50,000 PHN require both reviewers; the maximum technical single award is 50,000 PHN and the absolute maximum single award is 100,000 PHN.

The **250,000 PHN** Launch Enablement pot is for essential pre-KHAOS services such as legal compliance, security audit, infrastructure and launch operations. It is not founder compensation or a general cash-withdrawal balance.

## Release safety and deployment gate

Before KHAOS, all three predetermined release signers must approve the same release-manifest fingerprint. `armLaunch()` is irreversible once correctly armed, and any two of the three release signers may permanently abort a bad deployment before KHAOS. The intended design has no post-KHAOS pause, repricing, supply-mutation or upgrade control.

The public Buy UI remains withheld until one canonical RC10 v0.8 production deployment is verified and armed. Do not use RC7/RC9 addresses or send seed phrases/private keys to ChatGPT, BaseScan, Telegram, email or support forms.

## Testing status

The handoff includes deterministic source/economic checks, a behaviour model, a fixed-point curve stress model and fresh Solidity/Foundry evidence. The supplied gate record reports **72/72 Solidity/Foundry tests passing**, a 14,681-byte runtime and the full raw logs under `evidence/fresh_v08_evm/`.

The model/static checks can be rerun locally with the commands in `docs/TEST_HANDOFF_V08.md`; an independent local rerun is recommended when Foundry is available. The evidence does not mean the contract is audited, deployed or available for purchase.
