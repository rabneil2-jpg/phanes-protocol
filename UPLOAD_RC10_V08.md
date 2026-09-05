# Uploading the RC10 v0.8 handoff

This package is arranged so the complete handoff can be extracted into the root of the existing GitHub repository connected to Netlify.

## GitHub web upload

1. Create a branch or download a backup of the current repository first.
2. Open the existing public repository `rabneil2-jpg/phanes-protocol` on GitHub and select the `main` branch.
3. Extract this package. Upload the contents of the extracted `PHANES_HANDOFF_RC10_V08` folder into the repository root.
4. Replace `index.html`, `netlify.toml` and the root `README.md`. Delete the existing lowercase `readme.md`; it contains stale RC7/v0.7 language and must not remain alongside the new README.
5. Add or replace `src/`, `test/`, `script/`, `constitution/`, `evidence/`, `manifests/` and `docs/` from this handoff. Keep the supplied `netlify.toml` security headers.
6. Commit the replacement to `main` with a message such as `Publish PHANES RC10 v0.8 pre-mainnet handoff`.
7. Confirm the homepage shows **RC10 v0.8**, the **$0.12 terminal primary-issuance quote**, **pre-mainnet / not deployed**, and no wallet or Buy UI.

Because this repository is the Netlify source, the GitHub commit is the website deployment action. Do not use the older v0.7 site files or the separate v0.7 Sepolia rehearsal package in this tree. Netlify will build the repository using `netlify.toml` with the repository root as the publish directory.

The website is intentionally informational and has no wallet or Buy UI.

The GitHub upload does not deploy a token contract. Contract deployment remains a separately gated operation after the fresh Foundry/EVM run described in `TEST_HANDOFF_V08.md`.
