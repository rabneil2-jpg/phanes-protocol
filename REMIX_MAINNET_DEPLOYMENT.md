# RC10 v0.8 Base Mainnet — MetaMask browser route

This is the browser-wallet route for deploying and interacting with the exact RC10 v0.8 production source. It avoids exporting the Founder private key. Use only the official Remix site: `https://remix.ethereum.org`.

## 1. Prepare MetaMask

Use the Founder account:

`0xBE6D348d43083FC07BF4E453683AafF4da0C6a32`

Switch MetaMask to **Base Mainnet**, not Base Sepolia and not Ethereum Mainnet. The account must hold native Base ETH for gas. Base is available as a supported network in MetaMask; if it is not already listed, use MetaMask's Networks menu and add Base from the supported networks list.

## 2. Load and compile the source

1. Open `https://remix.ethereum.org`.
2. In File Explorer, upload `src/PHANES_RC10_v0_8.sol` from this package. Do not use an older RC7/RC10 file.
3. Open **Solidity Compiler**.
4. Select compiler **0.8.36**.
5. Enable the optimizer and set **200** runs.
6. Set the EVM version to **Cancun**.
7. Compile `PHANES_RC10_v0_8.sol`.

Warnings are acceptable; compilation errors are not. In Deploy & Run, select the `PHANES` contract, not `MockUSDC` or one of the vault contracts.

## 3. Deploy

1. Open **Deploy & Run Transactions**.
2. Set **Environment** to **Browser Extension** and approve the MetaMask connection.
3. Confirm the displayed account is exactly the Founder address above and the displayed network is Base Mainnet.
4. Leave **Value** at `0`.
5. Enter these constructor arguments exactly:

| Constructor field | Value |
|---|---|
| `paymentToken_` | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| `founder_` | `0xBE6D348d43083FC07BF4E453683AafF4da0C6a32` |
| `reviewerOne_` | `0xA4ac48B8eb1e639930Cc0ce3ACcAB5605D5DFe14` |
| `reviewerTwo_` | `0x6Fff69C4d3Bf4590e2518ff3CdF07De567b8F4Dc` |
| `rewardsExpiryTime_` | `2100000000` |

6. Before confirming MetaMask, re-check every address and the Base Mainnet network.
7. Click **Deploy** and confirm the single deployment transaction in MetaMask.

Do not click Deploy twice. If the transaction is pending, wait for it; if it fails, record the error before trying anything again.

## 4. Record the deployment graph

After the transaction mines, record:

- PHANES core address
- deployment transaction hash

In Remix's deployed PHANES contract, click the read-only getters and record the returned addresses for:

- `liquidityVault()`
- `reserveVault()`
- `founderVault()`
- `launchEnablementVault()`
- `rewardsVault()`

## 5. Verify and create the final manifest

Verify the deployed source before release approvals. Use Remix's verification option if configured, or BaseScan's **Verify and Publish** page with compiler 0.8.36, optimizer enabled/200 runs, EVM Cancun, MIT licence and contract `PHANES`.

Copy `manifests/RELEASE_MANIFEST_TEMPLATE_V08.json` to `manifests/RELEASE_MANIFEST_BASE_MAINNET_FINAL.json`. Fill every `FILL_AFTER_DEPLOY` field, including the five vault addresses, transaction hash, runtime code hash and `source_verified: true`. The payment token is the Base USDC address above; the Founder and reviewer fields must remain exactly as listed in this document.

Calculate the completed file's SHA-256 locally. The output is 64 hexadecimal characters; add `0x` before it when entering the `bytes32` approval field. Do not edit the file after calculating the hash.

## 6. Approvals without BaseScan Write Contract

If BaseScan has no Write Contract tab, keep the source compiled in Remix, use **Deploy & Run → Browser Extension**, choose **Add Contract**, and enter the new PHANES core address. Remix can load a deployed contract and interact with its functions without redeploying it.

Use the same final manifest hash for all three transactions, in this order:

1. Founder account calls `approveReleaseManifest(hash)` — expected mask `1`.
2. Reviewer 1 account `0xA4ac48B8eb1e639930Cc0ce3ACcAB5605D5DFe14` calls `approveReleaseManifest(hash)` — expected mask `3`.
3. Reviewer 2 account `0x6Fff69C4d3Bf4590e2518ff3CdF07De567b8F4Dc` calls `approveReleaseManifest(hash)` — expected mask `7`.

Each reviewer must switch MetaMask to the corresponding account on Base Mainnet and approve the transaction in their own wallet. Each wallet needs a small amount of Base ETH for gas. Read `releaseApprovalMask()` after each transaction.

## 7. Arm the launch

After the mask is exactly `7`, use the Founder account—or any account—to call `armLaunch(hash)` with the identical hash. Read `launchArmed()` and confirm it is `true`.

`armLaunch` is irreversible. Do not call it with a different hash, and do not call `executeLaunchAbort` unless the deployment is intentionally being permanently killed.

The current website package is informational and contains no Buy UI. Publish or enable a Buy UI only after the deployed source, final manifest and armed state have been checked.
