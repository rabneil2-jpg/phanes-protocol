# RC10 v0.8 production reviewer-address check

**Date:** 5 September 2026

| Check | Result |
|---|---|
| Founder / deployer in guarded scripts | `0xBE6D348d43083FC07BF4E453683AafF4da0C6a32` |
| Reviewer 1 in guarded scripts and manifest template | `0xA4ac48B8eb1e639930Cc0ce3ACcAB5605D5DFe14` |
| Reviewer 2 in guarded scripts and manifest template | `0x6Fff69C4d3Bf4590e2518ff3CdF07De567b8F4Dc` |
| Reviewer addresses distinct from founder and each other | **PASS** |
| Old exchange/deposit addresses absent from v0.8 production configuration | **PASS** |
| Production source changed by this update | **NO** |
| Production source SHA-256 | `70e342e76d553400ffc093c9dba69eda5ff6ad2fe6dc5828c1bd728ba53289be` |

This is a configuration consistency check, not proof of private-key control. The Founder and both reviewers must personally sign post-deployment `approveReleaseManifest` transactions from the corresponding MetaMask accounts on Base Mainnet before `armLaunch` can succeed.
