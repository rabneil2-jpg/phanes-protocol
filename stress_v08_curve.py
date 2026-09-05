#!/usr/bin/env python3
"""Deterministic stress model for the RC10 v0.8 fixed-point issuance curve.

This mirrors the integer arithmetic in PHANES_RC10_v0_8.sol.  It is deliberately
stdlib-only so it can run before Foundry is installed.  It does not claim to
replace Solidity compilation or EVM execution.
"""

import random


UNIT = 10_000
WAD = 10**18
PUBLIC_ALLOCATION = 17_000_000 * UNIT
PRICE_A = 10_000
PRICE_B = 23_820
PRICE_C = 86_180
TERMINAL_PRICE = 120_000
FULL_SALE_COST = 860_823_333_333


def price_at(q: int) -> int:
    if not 0 <= q <= PUBLIC_ALLOCATION:
        raise ValueError("q outside public allocation")
    x = (q * WAD) // PUBLIC_ALLOCATION
    linear = (PRICE_B * x) // WAD
    quadratic = (((PRICE_C * x) // WAD) * x) // WAD
    return PRICE_A + linear + quadratic


def cumulative_cost(q: int) -> int:
    if not 0 <= q <= PUBLIC_ALLOCATION:
        raise ValueError("q outside public allocation")
    term1 = (PRICE_A * q) // UNIT
    term2 = (PRICE_B * q * q) // (2 * PUBLIC_ALLOCATION * UNIT)
    term3 = (PRICE_C * q * q * q) // (3 * PUBLIC_ALLOCATION * PUBLIC_ALLOCATION * UNIT)
    return term1 + term2 + term3


def cost_between(start: int, end: int) -> int:
    if not 0 <= start <= end <= PUBLIC_ALLOCATION:
        raise ValueError("invalid cost range")
    return cumulative_cost(end) - cumulative_cost(start)


def quote_within_limit(start: int, max_payment: int, max_tokens: int) -> tuple[int, int]:
    if max_payment <= 0 or max_tokens <= 0 or start >= PUBLIC_ALLOCATION:
        return 0, 0
    max_tokens = min(max_tokens, PUBLIC_ALLOCATION - start)
    full_cost = cost_between(start, start + max_tokens)
    if full_cost <= max_payment:
        return max_tokens, full_cost

    low = 0
    high = max_tokens
    while low < high:
        mid = low + (high - low + 1) // 2
        if cost_between(start, start + mid) <= max_payment:
            low = mid
        else:
            high = mid - 1
    return low, cost_between(start, start + low)


def main() -> None:
    rng = random.Random(0x5048414E4553)
    checks = []

    def check(name: str, condition: bool, detail: str = "PASS") -> None:
        if not condition:
            raise AssertionError(f"{name}: {detail}")
        checks.append((name, detail))

    check("price_at_zero_is_0_01", price_at(0) == PRICE_A)
    check("price_at_full_is_0_12", price_at(PUBLIC_ALLOCATION) == TERMINAL_PRICE)
    check("full_sale_cost_is_860823_333333_usdc", cumulative_cost(PUBLIC_ALLOCATION) == FULL_SALE_COST)
    check("price_is_bounded_by_terminal", PRICE_A <= price_at(PUBLIC_ALLOCATION) <= TERMINAL_PRICE)

    # Prove the largest Solidity-side products used by the curve fit uint256.
    max_products = [
        PRICE_B * PUBLIC_ALLOCATION * PUBLIC_ALLOCATION,
        PRICE_C * PUBLIC_ALLOCATION * PUBLIC_ALLOCATION * PUBLIC_ALLOCATION,
        3 * PUBLIC_ALLOCATION * PUBLIC_ALLOCATION * UNIT,
    ]
    check("curve_intermediates_fit_uint256", max(max_products) < 2**256)

    monotonic_cases = 250_000
    sampled_qs = sorted(rng.randrange(PUBLIC_ALLOCATION + 1) for _ in range(monotonic_cases))
    previous_price = price_at(sampled_qs[0])
    for q in sampled_qs[1:]:
        p = price_at(q)
        assert PRICE_A <= p <= TERMINAL_PRICE
        assert p >= previous_price
        previous_price = p
    check("random_price_monotonic_and_bounded", True, f"{monotonic_cases} sorted cases")

    telescoping_cases = 250_000
    for _ in range(telescoping_cases):
        q0 = rng.randrange(PUBLIC_ALLOCATION + 1)
        q1 = rng.randrange(q0, PUBLIC_ALLOCATION + 1)
        q2 = rng.randrange(q1, PUBLIC_ALLOCATION + 1)
        c01 = cost_between(q0, q1)
        c12 = cost_between(q1, q2)
        c02 = cost_between(q0, q2)
        assert c01 >= 0 and c12 >= 0
        assert c01 + c12 == c02
    check("random_cost_nonnegative_and_telescoping", True, f"{telescoping_cases} triplets")

    quote_cases = 100_000
    for _ in range(quote_cases):
        start = rng.randrange(PUBLIC_ALLOCATION)
        max_tokens = rng.randrange(1, min(PUBLIC_ALLOCATION - start, 5_000_000) + 1)
        budget = rng.randrange(0, 2_000_000_000)
        tokens, payment = quote_within_limit(start, budget, max_tokens)
        assert payment <= budget
        assert 0 <= tokens <= max_tokens
        if tokens < max_tokens:
            next_cost = cost_between(start, start + tokens + 1)
            assert next_cost > budget
    check("random_affordable_quotes_are_maximal", True, f"{quote_cases} budget/request pairs")

    print("PHANES RC10 v0.8 FIXED-POINT CURVE STRESS MODEL")
    print("=" * 52)
    for name, detail in checks:
        print(f"PASS  {name}: {detail}")
    print(f"\nTOTAL PASS: {len(checks)}")
    print(f"RANDOM MONOTONIC/RANGE CASES: {monotonic_cases}")
    print(f"RANDOM TELESCOPING COST CASES: {telescoping_cases}")
    print(f"RANDOM AFFORDABLE-QUOTE CASES: {quote_cases}")
    print("NOTE: Python model only; fresh Solidity/Forge/EVM execution remains mandatory.")


if __name__ == "__main__":
    main()
