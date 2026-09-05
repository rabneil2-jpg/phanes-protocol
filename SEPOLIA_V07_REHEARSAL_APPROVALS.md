# Base Sepolia rehearsal approvals — RC10 v0.7 only

**Important:** This guide applies only to the already-deployed RC10 v0.7 rehearsal on Base Sepolia. It does **not** approve, arm or validate the RC10 v0.8 / $0.12 production candidate in this handoff. Do not mix the v0.7 address or manifest into the v0.8 mainnet release.

## Network and contract

- Network: **Base Sepolia**
- Chain ID: **84532**
- Core: `0x96F3F0D7861015DE14BCF1B41F5DbaDF47f48CB7`
- Manifest hash: `0x27b98fd023185af94d0d3e83ca8a1d07b843d23942409ea93e32b6014cd22572`
- Current release approval mask: `1` (founder approval already recorded)

The predetermined reviewer wallets are:

- Reviewer1: `0x64333a78f9b03C4e0bd2F0496ef3fF6c671211F8`
- Reviewer2: `0x8Abf9E6B52251C35E58C97daB6bb177A8876D471`

Each reviewer must use the wallet whose address is listed above. The founder key cannot substitute for either reviewer because the contract checks the caller address.

## Reviewer1 and Reviewer2

On Base Sepolia, open the verified core contract and write:

```text
approveReleaseManifest(
  0x27b98fd023185af94d0d3e83ca8a1d07b843d23942409ea93e32b6014cd22572
)
```

The call must be made once by Reviewer1 and once by Reviewer2. Each wallet needs a small amount of Base Sepolia ETH for gas. Never send seed phrases or private keys to anyone; the reviewer signs the transaction in their own wallet.

After each approval, read `releaseApprovalMask()` or `releaseSafetyStatus()` on the same core. The expected mask is:

```text
founder only       1
founder + one      3 or 5
all three          7
```

The order of Reviewer1 and Reviewer2 does not matter. Confirm that the manifest hash is unchanged and the mask is `7` before arming.

## Arm the rehearsal

Once the mask is `7`, **any wallet** may call:

```text
armLaunch(
  0x27b98fd023185af94d0d3e83ca8a1d07b843d23942409ea93e32b6014cd22572
)
```

The caller needs only Base Sepolia ETH for gas. Read `launchArmed()` afterwards and confirm it is `true`.

This only arms the v0.7 Sepolia rehearsal. It does not deploy or arm mainnet, does not authorize a real USDC sale, and does not validate the v0.8 curve. The v0.8 candidate requires its own fresh Foundry/EVM run, release manifest and deployment before mainnet.
