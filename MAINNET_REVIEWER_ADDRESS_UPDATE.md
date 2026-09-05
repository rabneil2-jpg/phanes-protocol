# RC10 v0.8 mainnet reviewer-address update

**Date:** 5 September 2026

This package replaces the two previously configured production reviewer addresses with the two self-custody MetaMask addresses supplied for the Base Mainnet deployment:

| Role | Address |
|---|---|
| Founder / deployer | `0xBE6D348d43083FC07BF4E453683AafF4da0C6a32` |
| Reviewer 1 | `0xA4ac48B8eb1e639930Cc0ce3ACcAB5605D5DFe14` |
| Reviewer 2 | `0x6Fff69C4d3Bf4590e2518ff3CdF07De567b8F4Dc` |

The order above is the order used by both guarded deployment scripts and the release-manifest template. These three addresses are constructor parameters and become immutable in the deployed contract.

The old reviewer addresses remain only in `docs/SEPOLIA_V07_REHEARSAL_APPROVALS.md`, which is explicitly historical RC10 v0.7 rehearsal documentation. They are not used by the v0.8 mainnet scripts.

An address alone cannot prove wallet control. After deployment, the Founder approves the exact final manifest hash first, then each reviewer connects the corresponding MetaMask account on **Base Mainnet** and personally signs `approveReleaseManifest` with that same hash. The approval mask must reach `7` before `armLaunch`. Never share a seed phrase or private key.

The production Solidity source was not changed by this update. Its SHA-256 remains `70e342e76d553400ffc093c9dba69eda5ff6ad2fe6dc5828c1bd728ba53289be`.
