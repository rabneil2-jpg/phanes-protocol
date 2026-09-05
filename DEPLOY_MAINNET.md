# Deploy RC10 v0.8 to Base Mainnet (founder only)

**Never paste a private key or seed phrase into any chat, website, or support form.**  
All signing happens on **your** machine under **your** control.

## Prerequisites (one-time)

1. Install Foundry (if not already present):
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```
2. Confirm versions:
   ```bash
   forge --version   # should be recent (1.8.x is fine)
   ```
3. Extract this handoff package and `cd` into the extracted folder (the one that contains `foundry.toml`, `src/`, `script/`, etc.).

4. Install the only dependency (forge-std):
   ```bash
   mkdir -p lib
   git clone --depth 1 https://github.com/foundry-rs/forge-std.git lib/forge-std
   ```
   (or `forge install foundry-rs/forge-std --no-commit` if the folder is already a git repo)

5. Optional but recommended — re-run the gate yourself:
   ```bash
   bash evidence/run_v08_release_gate.sh
   ```
   Expect: source hash match → 62 static → 37 behaviour → stress → 72/72 Forge PASS.

## Deployment command

If you want to deploy directly from MetaMask without exporting a private key, use the browser-wallet route in `docs/REMIX_MAINNET_DEPLOYMENT.md`. It deploys the same `PHANES` source with the same constructor values and is also the fallback interaction route if BaseScan does not expose a Write Contract tab.

You need a Base Mainnet RPC URL (Alchemy, Infura, QuickNode, public Base RPC, etc.).

### Option A — Private key stored only in your local environment (most common)

**Do this only on a machine you control. Never type the key into a chat.**

```bash
export PRIVATE_KEY="0xYOUR_FOUNDER_PRIVATE_KEY_HERE"   # local only – never share
export BASE_RPC="https://mainnet.base.org"              # or your paid RPC

forge script script/DeployRC10MainnetGuarded.s.sol:DeployRC10MainnetGuarded \
  --rpc-url "$BASE_RPC" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --verify \
  --chain-id 8453 \
  -vvvv
```

After it finishes, **immediately unset the key**:
```bash
unset PRIVATE_KEY
```

### Option B — Hardware wallet / Ledger (preferred if you have one)

```bash
forge script script/DeployRC10MainnetGuarded.s.sol:DeployRC10MainnetGuarded \
  --rpc-url "$BASE_RPC" \
  --ledger \
  --broadcast \
  --verify \
  --chain-id 8453 \
  -vvvv
```

(Follow the on-device prompts.)

### Option C — Interactive / keystore (also good)

```bash
# first create a keystore if you do not already have one
cast wallet import founder --interactive

forge script script/DeployRC10MainnetGuarded.s.sol:DeployRC10MainnetGuarded \
  --rpc-url "$BASE_RPC" \
  --account founder \
  --broadcast \
  --verify \
  --chain-id 8453 \
  -vvvv
```

## What the script does

- Requires `block.chainid == 8453` (Base Mainnet). It will revert on any other chain.
- Deploys `PHANES` with the hard-coded production addresses:
  - USDC = `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
  - Founder = `0xBE6D348d43083FC07BF4E453683AafF4da0C6a32`
  - Reviewer 1 = `0xA4ac48B8eb1e639930Cc0ce3ACcAB5605D5DFe14`
  - Reviewer 2 = `0x6Fff69C4d3Bf4590e2518ff3CdF07De567b8F4Dc`
- Emits a `DeploymentGraph` event with the core + all vault addresses.
- Does **not** arm the launch. Launch arming requires the three release-manifest approvals later.

## After the transaction confirms

1. Note the new **PHANES core address** from the broadcast log / Basescan.
2. Make a copy of `manifests/RELEASE_MANIFEST_TEMPLATE_V08.json` named `RELEASE_MANIFEST_BASE_MAINNET_FINAL.json`. Fill the copy with the new core/vault addresses, deployment transaction hash, runtime code hash and `source_verified: true` after verification. The deployment does not emit the final manifest fingerprint.
3. Calculate the SHA-256 of that completed JSON file locally. In Git Bash use:
   ```bash
   sha256sum manifests/RELEASE_MANIFEST_BASE_MAINNET_FINAL.json
   ```
   In PowerShell use:
   ```powershell
   (Get-FileHash .\manifests\RELEASE_MANIFEST_BASE_MAINNET_FINAL.json -Algorithm SHA256).Hash.ToLower()
   ```
   Prefix the resulting 64-character value with `0x` when entering it as `bytes32` in a wallet interface. Every signer must use the identical value.
4. On Basescan, verify the source matches the exact file in this package (SHA-256 above).
5. The Founder first calls:
   ```text
   approveReleaseManifest( bytes32 exactManifestHash )
   ```
6. Reviewer 1 and Reviewer 2 each call:
   ```text
   approveReleaseManifest( bytes32 exactManifestHash )
   ```
7. Confirm the approval mask reaches `7`; then the founder (or any account) can call `armLaunch(exactManifestHash)`.
8. Only after arming should any public Buy UI be published.

## Gas & funding reminder

~0.005 ETH on the founder address is enough for the creation transaction plus a small reserve.  
If the transaction fails for “insufficient funds”, top up a little more and re-broadcast (Foundry will reuse the same nonce/script).

## Safety checklist before you press broadcast

- [ ] You are on **Base Mainnet** (chain ID 8453)
- [ ] The signing address is exactly `0xBE6D348d43083FC07BF4E453683AafF4da0C6a32`
- [ ] You have **not** shared the private key or seed with anyone
- [ ] You re-checked the source SHA-256 matches `70e342e76d553400ffc093c9dba69eda5ff6ad2fe6dc5828c1bd728ba53289be`
- [ ] You understand that after deployment the three release addresses are immutable

If anything looks wrong, **do not broadcast**. Ask for clarification first.
