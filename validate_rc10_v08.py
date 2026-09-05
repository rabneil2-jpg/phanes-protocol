from pathlib import Path
import re, json, hashlib

root=Path(__file__).resolve().parents[1]
src_path=root/'src/PHANES_RC10_v0_8.sol'
src=src_path.read_text()
constitution=json.loads((root/'constitution/PHANES_RC10_v0_8_CONSTITUTION.json').read_text())
checks=[]

def ok(name, cond, detail=''):
    if not cond:
        raise AssertionError(f'{name}: {detail}')
    checks.append((name, detail or 'PASS'))

def strip_solidity(s):
    s=re.sub(r'//.*','',s)
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S)
    s=re.sub(r'"(?:\\.|[^"\\])*"','""',s)
    return s

clean=strip_solidity(src)
for a,b,n in [('(',')','parentheses'),('{','}','braces'),('[',']','brackets')]:
    depth=0
    bad=False
    for ch in clean:
        if ch==a: depth+=1
        elif ch==b:
            depth-=1
            if depth<0:
                bad=True; break
    ok(f'lexical_{n}_balanced', not bad and depth==0, f'final depth={depth}')

KHAOS=1_797_886_200
TRADING=1_798_059_000
CHRONOS=1_808_427_000
ANANKE=1_819_054_200
AITHER=1_829_508_600
OION=1_840_049_400
OION_CLOSE=1_843_714_740
EMERGENCE=1_853_268_600
ok('trading_start_is_exactly_khaos_plus_48h', TRADING-KHAOS==48*3600, str(TRADING-KHAOS))
for literal in [
    'uint64 public constant KHAOS_START = 1_797_886_200',
    'uint64 public constant TRANSFER_RELEASE_START = 1_798_059_000',
    'uint64 public constant SECONDARY_TRADING_START = TRANSFER_RELEASE_START',
    'uint64 public constant FULL_TRANSFERABILITY_TIME = TRANSFER_RELEASE_START',
    'uint64 public constant FINAL_SEAL_START = OION_CLOSE',
    'uint64 public constant EMERGENCE_TIME = 1_853_268_600',
]:
    ok('source_constant_'+literal.split('constant ')[1].split()[0], literal in src, literal)

allocs=constitution['allocations']
ok('genesis_allocations_sum_21m',
   allocs['publicIssuance']+allocs['protocolLiquidity']+allocs['founder']+allocs['launchEnablement']+allocs['securityAndEcosystemRewards']==21_000_000,
   str(allocs))
ok('founder_5x200k_equals_1m', constitution['founderRelease']['tranche']*5==allocs['founder'])
for i,ts in enumerate([KHAOS,CHRONOS,ANANKE,AITHER,OION],start=1):
    formatted=f'{ts:,}'.replace(',','_')
    ok(f'founder_release_{i}_matches_epoch', f'RELEASE_{i} = {formatted}' in src, formatted)
ok('founder_tranche_is_200k', 'TRANCHE = 200_000 * UNIT' in src)

ok('no_old_transfer_milestones', 'PUBLIC_TRANSFER_MILESTONE' not in src)
ok('no_transfer_releasing_state', 'TRANSFER_RELEASING' not in src)
ok('final_seal_state_present', 'FINAL_SEAL' in src)
ok('no_150k_public_cap', '150_000' not in src and '150000' not in src)
ok('binary_transfer_unlock_rule', 'return timestamp < TRANSFER_RELEASE_START ? 0 : TRANSFER_SCALE;' in src)
ok('binary_transfer_bps_rule', 'return timestamp < TRANSFER_RELEASE_START ? 0 : BPS;' in src)
ok('full_balance_transferable_after_gate', 'return balanceOf[wallet];' in src and 'if (block.timestamp < TRANSFER_RELEASE_START) return 0;' in src)

transfer_section=src[src.index('function approve(address spender'):src.index('// Narrow Rewards Vault bypass')]
ok('finalization_only_after_oion_close_in_transfer_interface',
   transfer_section.count('if (block.timestamp >= OION_CLOSE) _finalizeIfNeeded();')==3,
   f"count={transfer_section.count('if (block.timestamp >= OION_CLOSE) _finalizeIfNeeded();')}")
ok('no_unconditional_finalize_in_transfer_interface', '\n        _finalizeIfNeeded();' not in transfer_section)

ok('final_seal_uses_symbolic_emergence_not_transfer_gate',
   'if (t >= OION_CLOSE && t < EMERGENCE_TIME) return PublicState.FINAL_SEAL;' in src)
ok('final_seal_next_timestamp_symbolic_emergence',
   'if (s == PublicState.FINAL_SEAL) return EMERGENCE_TIME;' in src)

liq_block=src[src.index('contract PHANESLiquidityVault'):src.index('contract PHANESReserveVault')]
liq_code=strip_solidity(liq_block)
ok('liquidity_vault_has_no_withdraw_function', re.search(r'function\s+withdraw\s*\(',liq_code) is None)
ok('liquidity_vault_has_no_rescue_function', re.search(r'function\s+rescue\s*\(',liq_code) is None)
ok('liquidity_vault_has_no_arbitrary_call_function', re.search(r'function\s+call\s*\(',liq_code) is None and 'delegatecall(' not in liq_code)
ok('no_auto_dex_adapter_in_candidate', 'does NOT yet implement the final concentrated-liquidity adapter' in src)
ok('constitution_marks_liquidity_separate',
   constitution['protocolLiquidity']['separateFromTransferability'] is True and
   constitution['protocolLiquidity']['automaticDexDumpAtSecondaryTransferOpen'] is False)

def eligible(allocation,start,t):
    opening=allocation//5
    if t < start: return 0
    if t >= start+48*3600: return allocation
    return opening + (allocation-opening)*(t-start)//(48*3600)
ok('khaos_open_20pct', eligible(5_000_000,KHAOS,KHAOS)==1_000_000)
ok('khaos_24h_60pct', eligible(5_000_000,KHAOS,KHAOS+24*3600)==3_000_000)
ok('khaos_48h_100pct', eligible(5_000_000,KHAOS,TRADING)==5_000_000)

A=0.01; B=0.023820; C=0.086180
ok('curve_start_0_01', abs(A-0.01)<1e-12)
ok('curve_end_0_12', abs((A+B+C)-0.12)<1e-12, str(A+B+C))
ok('source_curve_price_a', 'uint256 private constant PRICE_A = 10_000;' in src)
ok('source_curve_price_b', 'uint256 private constant PRICE_B = 23_820;' in src)
ok('source_curve_price_c', 'uint256 private constant PRICE_C = 86_180;' in src)
ok('constitution_curve_formula', constitution['pricing']['formula']=='P(x)=0.01+0.023820x+0.086180x^2')
ok('constitution_terminal_price_0_12', constitution['pricing']['terminalPriceUsd']==0.12)
ok('constitution_full_sale_model', abs(constitution['pricing']['modeledGrossAtFullPublicSaleUsd']-860823.333333)<1e-6)

json_bytes=(root/'constitution/PHANES_RC10_v0_8_CONSTITUTION.json').read_bytes()
csha=hashlib.sha256(json_bytes).hexdigest()
ok('constitution_sha_matches_source', f'0x{csha}' in src, csha)

tests=list((root/'test').glob('*.sol'))
test_count=0
for f in tests:
    txt=f.read_text()
    test_count += len(re.findall(r'^\s*function\s+test(?:Fuzz)?[A-Za-z0-9_]*\s*\(',txt,flags=re.M))
    if f.name != 'PHANES_ADVERSARIAL_PAYMENT_TOKENS_RC10.sol':
        ok(f'import_v08_{f.name}', '../src/PHANES_RC10_v0_8.sol' in txt)
ok('test_count_72', test_count==72, f'count={test_count}')

combined='\n'.join(f.read_text() for f in tests)
for needle,name in [
    ('testTransferLockedOneSecondBeforeTradingStart','pre_gate_transfer_lock_test'),
    ('testFullBalanceTransferableAtExactTradingStart','exact_gate_full_transfer_test'),
    ('testTradingOpeningDoesNotFinalizePrimaryIssuance','no_early_finalize_regression_test'),
    ('testChronosPurchaseIsImmediatelyTransferable','later_epoch_transfer_test'),
    ('testOionPurchaseIsImmediatelyTransferable','oion_transfer_test'),
    ('testFinalSealDoesNotRelockHolders','final_seal_no_relock_test'),
    ('testSymbolicEmergenceCreatesNoHolderUnlockCliff','emergence_no_cliff_test'),
    ('testFounderKhaosTrancheSharesTheSame48HourTransferGate','founder_gate_test'),
    ('testProtocolLiquidityAllocationDoesNotAutoDumpAtTradingOpen','liquidity_separation_test'),
]:
    ok(name, needle in combined)

mainnet_script=(root/'script/DeployRC10MainnetGuarded.s.sol').read_text()
sepolia_script=(root/'script/DeployRC10SepoliaGuarded.s.sol').read_text()
ok('guarded_deploy_scripts_point_to_v08', '../src/PHANES_RC10_v0_8.sol' in mainnet_script and '../src/PHANES_RC10_v0_8.sol' in sepolia_script and 'BASE_MAINNET_CHAIN_ID = 8453' in mainnet_script and 'BASE_SEPOLIA_CHAIN_ID = 84532' in sepolia_script)

out_lines=['PHANES RC10 v0.8 STATIC / MODEL VALIDATION','='*52]
for n,d in checks:
    out_lines.append(f'PASS  {n}: {d}')
out_lines += ['',f'TOTAL PASS: {len(checks)}',
              'NOTE: This validation checks source structure, constants, economics, timestamp/model invariants and test-suite wiring.',
              'NOTE: It is NOT a substitute for Solidity compilation or Forge/EVM execution.']
print('\n'.join(out_lines))
