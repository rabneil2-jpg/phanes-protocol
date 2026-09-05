# PHANES RC10 v0.8 — current handoff status

**Date:** 5 September 2026  
**Status:** Gate green. Ready for founder-signed Base Mainnet deployment. No production contract has been deployed yet.

## The one wallet that must sign the deployment

```text
Founder / deployer: 0xBE6D348d43083FC07BF4E453683AafF4da0C6a32
```

- Network: **Base Mainnet** (chain ID **8453**)
- Asset: **native ETH**
- Working target already funded: **~0.005 ETH** is sufficient for gas + reserve

Do **not** send deployment funding to either reviewer address.

## Production signer addresses (immutable once deployed)

```text
Founder:   0xBE6D348d43083FC07BF4E453683AafF4da0C6a32
Reviewer1: 0xA4ac48B8eb1e639930Cc0ce3ACcAB5605D5DFe14
Reviewer2: 0x6Fff69C4d3Bf4590e2518ff3CdF07De567b8F4Dc
```

## Gate status (fresh)

- Source SHA-256 still `70e342e76d553400ffc093c9dba69eda5ff6ad2fe6dc5828c1bd728ba53289be`
- 62/62 static · 37/37 behaviour · 600 000 curve stress cases · **72/72 Forge PASS**
- PHANES runtime 14 681 B (under 24 576 B limit)
- One test file fixed for a Foundry `vm.prank` footgun; **Solidity source was not touched**

Full evidence is under `evidence/`. See `evidence/TEST_STATUS_V08.md`.

## What you do next

1. Confirm the founder wallet above is funded on Base Mainnet.
2. Follow **`DEPLOY_MAINNET.md`** or the MetaMask browser route in **`docs/REMIX_MAINNET_DEPLOYMENT.md`** (this package).
3. After the creation transaction confirms, record the new contract and vault addresses from the `DeploymentGraph` event.
4. Complete the final release manifest with those addresses, verify the source, and calculate its SHA-256 fingerprint locally. The deployment does not emit the final manifest fingerprint.
5. The Founder calls `approveReleaseManifest` with that calculated hash.
6. Reviewer 1 and Reviewer 2 each call `approveReleaseManifest` with the same exact hash.
7. Confirm the approval mask reaches `7`, then the Founder (or any account) calls `armLaunch`.
8. Only then publish any Buy UI.

**Nothing is sent until you approve the transaction in your own wallet.**  
Never share seed phrases or private keys with anyone (including this chat, BaseScan, Telegram, email, or “support”).
