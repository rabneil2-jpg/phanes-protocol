# RC10 v0.8 transfer architecture freeze record — 5 September 2026

**Status:** PRE-MAINNET CANDIDATE · NOT AUDITED · NOT DEPLOYED

## Material change from v0.6
- KHAOS still opens **21 Dec 2026 20:50 UTC**.
- KHAOS public eligibility remains **20% immediately + 80% continuously over 48 hours**.
- Holder transfer/approve/transferFrom are locked only during that same 48-hour opening window.
- At **23 Dec 2026 20:50 UTC**, PHN becomes **100% transferable and never relocks**.
- CHRONOS / ANANKE / AITHER / OION purchases are transferable immediately on receipt.
- The 2028 symbolic Final Seal / PHANES emergence sequence remains narrative/protocol state only; it no longer creates holder unlocks.
- Founder stays **5 × 200,000 PHN**, released at the five epoch openings.
- Protocol-owned 2m PHN liquidity remains separate and does not auto-deploy at the transfer gate.

## Fingerprints
- Source SHA-256: `70e342e76d553400ffc093c9dba69eda5ff6ad2fe6dc5828c1bd728ba53289be`
- Constitution SHA-256: `6c5f96f410cc3c84cf1e9dec8016de7e8c8efe59396e45db25c962c08b20808f`

## Validation
- Static/model validation: **62/62 PASS**.
- Fixed-point curve stress model: **600,000 randomized cases PASS**.
- Forge test definitions: **72 prepared**.
- Fresh v0.8 Forge/EVM execution: **INCLUDED in `evidence/fresh_v08_evm/` and summarized in `evidence/TEST_STATUS_V08.md`; independent local rerun recommended**.
