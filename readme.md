# PHANES

Official public website source for the deployed PHANES RC7 protocol on Base mainnet.

## Production identity
- Network: Base mainnet (chain ID 8453)
- Core: `0xdE0017F454597dc9D5602B0cB7004C6355B3d1B3`
- Payment asset: native Base USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- Frozen RC7 source SHA-256: `541980787467de64d621299257d295d0a73847a1d08fe899d453e0bf53e84127`
- RC7 constitution fingerprint: `3faccb66f3cd0c8e4c512cf0c4e7eb2b7511518da42acc2cbb88eb55eff5a01a`
- Fixed supply: 21,000,000 PHN
- Current phase (September 2026): PRELAUNCH
- KHAOS contract gate: 21 December 2026, 20:50 UTC
- Emergence / public transfer unlock: 20 March 2030, 13:51 UTC

## Deployed RC7 public issuance rules
- KHAOS, CHRONOS, ANANKE and AITHER are fixed normal epochs.
- 20% of each normal epoch is eligible immediately; the remaining 80% becomes eligible continuously over 48 hours.
- Maximum single purchase: 150,000 PHN per transaction. This is not a cumulative wallet cap.
- Unsold normal-epoch PHN rolls into OION rather than enlarging the next normal epoch.
- OION is the final public issuance window.
- After OION closes, remaining public PHN is no longer sale inventory. A permissionless finalization transaction moves the deterministic remainder into the PHANES Reserve and seals it. It is not burned and is not founder property.
- Public ERC-20 transfers remain locked until Emergence.

## Current release status
- Mainnet deployment: DEPLOYED
- Frozen production source: RC7 LOCKED
- Explorer source verification: PENDING
- Independent security audit: NOT COMPLETED
- Specialist legal/compliance route: unresolved
- Website purchase controls: DISABLED during current prelaunch preparation

The RC7 contract itself has no separate founder-controlled public-sale start switch. Its encoded time/state rules determine contract-level acquisition availability. A protocol timestamp does not by itself create legal permission to promote or acquire PHN in any jurisdiction.

## Risk status
**UNAUDITED · EXPERIMENTAL · HIGH RISK**

The deployed contracts are not independently audited and are immutable. Smart-contract failure and total loss are possible. Deployment or explorer verification is not an audit.

Security reports: `phanessecurity@proton.me`
