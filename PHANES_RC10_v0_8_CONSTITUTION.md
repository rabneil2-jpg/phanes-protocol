# PHANES RC10 v0.8 constitution freeze — 5 September 2026

**Status:** PRE-MAINNET PRODUCTION CANDIDATE · NOT AUDITED · NOT DEPLOYED

## Locked economics

| Item | Value |
|---|---|
| Total supply | **21,000,000 PHN** |
| Public issuance | **17,000,000 PHN** |
| Protocol liquidity | **2,000,000 PHN** |
| Founder allocation | **1,000,000 PHN** |
| Founder release | **200,000 PHN at each of KHAOS, CHRONOS, ANANKE, AITHER and OION** |
| Launch enablement | **250,000 PHN** |
| Security & ecosystem rewards | **750,000 PHN** |
| Public buyer cap | **None** |
| Pricing | Continuous global curve; no epoch reset |
| Terminal primary-issuance quote | **$0.12 at full 17,000,000 PHN public acquisition** |

## KHAOS

- Opens: **21 December 2026 · 20:50 UTC**
- Allocation: **5,000,000 PHN**
- **20%** globally eligible immediately
- Remaining **80%** globally eligible continuously over the following **48 hours**
- KHAOS fair-access envelope completes: **23 December 2026 · 20:50 UTC**

## Secondary transferability — v0.8 carried rule

The old RC10 v0.6 rule that kept public transfers locked until 2028 is **superseded**.

The v0.8 rule is:

> **PHN transfers, approvals and secondary-market compatibility are locked only during the first 48 hours of KHAOS. At 23 December 2026 · 20:50 UTC, full transferability becomes permanently available and never relocks.**

Consequences:

- KHAOS buyers cannot transfer during the first 48 hours.
- At the 48-hour boundary, all PHN already held by public buyers becomes fully transferable.
- Purchases made in CHRONOS, ANANKE, AITHER and OION are immediately transferable on receipt because the transfer gate has already opened.
- Founder KHAOS tranche becomes releasable at KHAOS but is subject to the same public transfer gate until 23 Dec 2026; later founder tranches are transferable immediately after release.
- Rewards / launch allocations received before the transfer opening remain non-transferable until 23 Dec 2026.
- There is **no 2028 holder unlock event** and **no 2030 holder unlock event**.

## Protocol liquidity is separate

The **2,000,000 PHN protocol-liquidity allocation does not automatically enter a DEX at the transfer opening**.

Secondary transferability and protocol-owned liquidity deployment are separate mechanisms.

The current v0.8 candidate:
- permits normal ERC-20 transfer / approve / transferFrom from 23 Dec 2026;
- does **not** implement a discretionary 2m PHN DEX dump;
- retains the protocol-liquidity allocation in the dedicated Liquidity Vault;
- leaves the final concentrated-liquidity adapter as a separate release-gated engineering item.

A third party may create a market once PHN is transferable. An official protocol-owned market still requires the separately tested liquidity adapter / pool deployment.

## Epoch sequence

**KHAOS → CHRONOS → ANANKE → AITHER → OION → THE FINAL SEAL → PHANES**

- KHAOS — 21 Dec 2026 20:50 UTC
- CHRONOS — 22 Apr 2027 20:50 UTC
- ANANKE — 23 Aug 2027 20:50 UTC
- AITHER — 22 Dec 2027 20:50 UTC
- OION — 22 Apr 2028 20:50 UTC
- THE FINAL SEAL begins when OION closes — 04 Jun 2028 06:59 UTC
- PHANES symbolic emergence — 22 Sep 2028 20:50 UTC

**Important:** THE FINAL SEAL / PHANES emergence no longer controls holder transferability. Holders remain fully transferable throughout these later protocol states.

## Curve

`P(x) = 0.01 + 0.023820x + 0.086180x²`

where `x = cumulative public PHN acquired / 17,000,000`.

The curve begins at **$0.01** and reaches a mathematical terminal primary-issuance quote of **$0.12** only when the full 17,000,000 PHN public allocation has been acquired. Under the same curve shape, the modelled gross USDC committed at a complete public sellout is approximately **$860,823.33**. This is an issuance calculation, not a market-price forecast, floor, promise or guarantee.

The curve:
- does not reset between epochs;
- applies to primary issuance only;
- coexists with secondary-market price discovery after 23 Dec 2026.

## Release safety

Before KHAOS:
- all three predetermined release signers must approve the **same release manifest fingerprint**;
- `armLaunch()` is irreversible once correctly armed;
- any two of the three release signers may permanently abort a bad deployment before KHAOS;
- no post-KHAOS pause / repricing / supply mutation / upgrade control is introduced.

## Superseded rules

Do **not** reintroduce:
- RC7's 150,000 PHN transaction cap;
- RC7's March-2030 public transfer cliff;
- RC10 v0.6's June–September 2028 staged holder transfer release;
- the old founder 125,000-PHN post-2030 vesting schedule.

## Constitution fingerprint

SHA-256 of `PHANES_RC10_v0_8_CONSTITUTION.json`:

`6c5f96f410cc3c84cf1e9dec8016de7e8c8efe59396e45db25c962c08b20808f`
