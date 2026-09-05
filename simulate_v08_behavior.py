#!/usr/bin/env python3
import random, math

UNIT=10_000
KHAOS=1_797_886_200
TRADING=1_798_059_000
CHRONOS=1_808_427_000
ANANKE=1_819_054_200
AITHER=1_829_508_600
OION=1_840_049_400
OION_CLOSE=1_843_714_740
EMERGENCE=1_853_268_600
D48=48*3600
EPOCHS=[(KHAOS,CHRONOS,5_000_000),(CHRONOS,ANANKE,4_500_000),(ANANKE,AITHER,4_000_000),(AITHER,OION,3_500_000)]
FOUNDER_RELEASES=[KHAOS,CHRONOS,ANANKE,AITHER,OION]
FOUNDER_TRANCHE=200_000

passes=[]
def check(name, cond, detail=''):
    if not cond: raise AssertionError(f'{name}: {detail}')
    passes.append((name, detail or 'PASS'))

def eligible(allocation,start,t):
    if t < start: return 0
    opening=allocation//5
    elapsed=t-start
    if elapsed>=D48: return allocation
    return opening + ((allocation-opening)*elapsed)//D48

def transfer_fraction(t):
    return 0 if t<TRADING else 1

def founder_cumulative(t):
    return FOUNDER_TRANCHE*sum(t>=r for r in FOUNDER_RELEASES)

check('trading_exactly_48h_after_khaos',TRADING-KHAOS==D48)
check('transfer_locked_1s_before',transfer_fraction(TRADING-1)==0)
check('transfer_full_at_boundary',transfer_fraction(TRADING)==1)
check('transfer_never_relocks',all(transfer_fraction(t)==1 for t in [TRADING,CHRONOS,ANANKE,AITHER,OION,OION_CLOSE,EMERGENCE,EMERGENCE+10**9]))
check('khaos_opening_20pct',eligible(5_000_000,KHAOS,KHAOS)==1_000_000)
check('khaos_halfway_60pct',eligible(5_000_000,KHAOS,KHAOS+D48//2)==3_000_000)
check('khaos_48h_100pct',eligible(5_000_000,KHAOS,TRADING)==5_000_000)
for idx,(start,end,allocation) in enumerate(EPOCHS):
    check(f'epoch_{idx}_opening_20pct',eligible(allocation,start,start)==allocation//5)
    check(f'epoch_{idx}_48h_full',eligible(allocation,start,start+D48)==allocation)
    # monotonic eligibility sampled across window
    vals=[eligible(allocation,start,start+(D48*i)//100) for i in range(101)]
    check(f'epoch_{idx}_eligibility_monotonic',all(a<=b for a,b in zip(vals,vals[1:])))

for i,r in enumerate(FOUNDER_RELEASES):
    before=founder_cumulative(r-1)
    at=founder_cumulative(r)
    check(f'founder_release_{i+1}_adds_200k',at-before==200_000,f'{before}->{at}')
check('founder_total_1m',founder_cumulative(OION)==1_000_000)
check('founder_pre_khaos_zero',founder_cumulative(KHAOS-1)==0)
check('founder_khaos_wallet_still_transfer_locked',founder_cumulative(KHAOS)==200_000 and transfer_fraction(KHAOS)==0)
check('founder_khaos_tranche_transferable_after_gate',founder_cumulative(TRADING)==200_000 and transfer_fraction(TRADING)==1)

# Global issuance curve reference checks.
def p(x): return 0.01 + 0.023820*x + 0.086180*x*x
check('curve_start_0_01',abs(p(0)-0.01)<1e-15)
check('curve_end_0_12',abs(p(1)-0.12)<1e-12)
xs=[i/10000 for i in range(10001)]
check('curve_monotonic_10001_points',all(p(a)<=p(b) for a,b in zip(xs,xs[1:])))
check('curve_positive_everywhere',all(p(x)>0 for x in xs))

# Random invariant stress: eligibility stays within allocation, transfer gate is binary/permanent,
# founder cumulative never exceeds 1m, and no artificial wallet purchase cap is modelled.
rng=random.Random(0x5048414E4553)
for _ in range(100_000):
    idx=rng.randrange(4)
    start,end,allocation=EPOCHS[idx]
    t=rng.randrange(KHAOS-10_000,EMERGENCE+10_000)
    e=eligible(allocation,start,t)
    assert 0<=e<=allocation
    assert transfer_fraction(t) in (0,1)
    if t>=TRADING: assert transfer_fraction(t)==1
    f=founder_cumulative(t)
    assert 0<=f<=1_000_000 and f%200_000==0
check('randomized_invariants_100000_cases',True)

# Buyer-cap regression: deliberately test amounts above old 150k ceiling at model level.
for amount in [150_001,200_000,500_000,1_000_000]:
    # Only global eligible inventory constrains amount, not a per-buyer threshold.
    check(f'no_old_150k_cap_amount_{amount}',amount<=eligible(5_000_000,KHAOS,TRADING))

print('PHANES RC10 v0.8 EXECUTED BEHAVIOUR / ECONOMIC MODEL')
print('='*62)
for name,detail in passes:
    print(f'PASS  {name}: {detail}')
print(f'\nTOTAL PASS: {len(passes)}')
print('RANDOMIZED INVARIANT CASES: 100000')
print('NOTE: Executed Python model validation; not Solidity bytecode/EVM execution.')
