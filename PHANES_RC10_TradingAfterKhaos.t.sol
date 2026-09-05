// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import "forge-std/Test.sol";
import "../src/PHANES_RC10_v0_8.sol";

contract PHANESRC10TradingAfterKhaosTest is Test {
    uint256 constant UNIT = 10_000;
    uint256 constant USDC = 1e6;
    uint256 constant WAD = 1e18;

    uint64 constant KHAOS = 1_797_886_200;
    uint64 constant TRADING_START = 1_798_059_000; // KHAOS + 48h
    uint64 constant CHRONOS = 1_808_427_000;
    uint64 constant OION = 1_840_049_400;
    uint64 constant OION_CLOSE = 1_843_714_740;
    uint64 constant EMERGENCE = 1_853_268_600;

    address founder = address(0x8101);
    address reviewer1 = address(0x8102);
    address reviewer2 = address(0x8103);
    address buyer = address(0x8201);
    address buyer2 = address(0x8202);
    address recipient = address(0x8203);
    address spender = address(0x8204);

    MockUSDC usdc;
    PHANES phn;

    bytes32 constant MANIFEST = keccak256("phanes-rc10-v08-test-manifest");

    function _armLaunch() internal {
        vm.prank(founder); phn.approveReleaseManifest(MANIFEST);
        vm.prank(reviewer1); phn.approveReleaseManifest(MANIFEST);
        vm.prank(reviewer2); phn.approveReleaseManifest(MANIFEST);
        phn.armLaunch(MANIFEST);
    }

    function setUp() public {
        vm.warp(1_790_000_000);
        usdc = new MockUSDC(100_000_000 * USDC);
        phn = new PHANES(address(usdc), founder, reviewer1, reviewer2, uint64(2_100_000_000));
        usdc.transfer(buyer, 20_000_000 * USDC);
        usdc.transfer(buyer2, 20_000_000 * USDC);
        vm.prank(buyer); usdc.approve(address(phn), type(uint256).max);
        vm.prank(buyer2); usdc.approve(address(phn), type(uint256).max);
        _armLaunch();
    }

    function _buy(address who, uint8 stage, uint256 budget) internal returns (uint256 got) {
        vm.prank(who);
        (uint256 spent, uint256 quoted) = phn.quoteForStage(stage, budget);
        assertGt(spent, 0);
        assertGt(quoted, 0);
        vm.prank(who);
        (, got) = phn.buy(stage, budget, quoted, uint64(block.timestamp + 300));
        assertEq(got, quoted);
    }

    function _buyKhaos(address who) internal returns (uint256 got) {
        vm.warp(KHAOS);
        return _buy(who, 0, 10_000_000 * USDC);
    }

    function testTradingGateIdentityIsExactKhaosPlus48Hours() public {
        assertEq(phn.KHAOS_START(), KHAOS);
        assertEq(phn.TRANSFER_RELEASE_START(), TRADING_START);
        assertEq(phn.SECONDARY_TRADING_START(), TRADING_START);
        assertEq(phn.FULL_TRANSFERABILITY_TIME(), TRADING_START);
        assertEq(TRADING_START - KHAOS, 48 hours);
        assertEq(phn.EMERGENCE_TIME(), EMERGENCE);
    }

    function testTransferLockedOneSecondBeforeTradingStart() public {
        _buyKhaos(buyer);
        vm.warp(TRADING_START - 1);
        assertEq(phn.transferableBalance(buyer), 0);
        assertEq(phn.transferUnlockBps(), 0);
        vm.expectRevert(PHANES.TransfersLocked.selector);
        vm.prank(buyer); phn.transfer(recipient, 1);
    }

    function testApprovalLockedOneSecondBeforeTradingStart() public {
        _buyKhaos(buyer);
        vm.warp(TRADING_START - 1);
        vm.expectRevert(PHANES.TransfersLocked.selector);
        vm.prank(buyer); phn.approve(spender, 1);
    }

    function testFullBalanceTransferableAtExactTradingStart() public {
        uint256 got = _buyKhaos(buyer);
        vm.warp(TRADING_START);
        assertEq(phn.transferUnlockWad(), WAD);
        assertEq(phn.transferUnlockBps(), 10_000);
        assertEq(phn.transferableBalance(buyer), got);
        vm.prank(buyer); phn.transfer(recipient, got);
        assertEq(phn.balanceOf(recipient), got);
        assertEq(phn.balanceOf(buyer), 0);
    }

    function testApproveAndTransferFromWorkAtExactTradingStart() public {
        uint256 got = _buyKhaos(buyer);
        vm.warp(TRADING_START);
        vm.prank(buyer); assertTrue(phn.approve(spender, type(uint256).max));
        vm.prank(spender); phn.transferFrom(buyer, recipient, got);
        assertEq(phn.balanceOf(recipient), got);
        assertEq(phn.balanceOf(buyer), 0);
    }

    function testKhaosFairAccessEnvelopeStillCompletesAtTradingStart() public {
        vm.warp(KHAOS);
        assertEq(phn.normalEpochTimeEligible(0, KHAOS), 1_000_000 * UNIT);
        vm.warp(KHAOS + 24 hours);
        assertEq(phn.normalEpochTimeEligible(0, block.timestamp), 3_000_000 * UNIT);
        vm.warp(TRADING_START);
        assertEq(phn.normalEpochTimeEligible(0, block.timestamp), 5_000_000 * UNIT);
    }

    function testTradingOpeningDoesNotFinalizePrimaryIssuance() public {
        uint256 got = _buyKhaos(buyer);
        vm.warp(TRADING_START);
        vm.prank(buyer); phn.transfer(recipient, got / 2);
        assertFalse(phn.publicIssuanceFinalized());
        assertGt(phn.balanceOf(address(phn)), 0);
        assertEq(uint8(phn.protocolState()), uint8(PHANES.PublicState.ACTIVE));
    }

    function testPrimaryBuyAfterTradingStartIsImmediatelyTransferable() public {
        vm.warp(TRADING_START);
        uint256 got = _buy(buyer, 0, 10_000_000 * USDC);
        assertEq(phn.transferableBalance(buyer), got);
        vm.prank(buyer); phn.transfer(recipient, got);
        assertEq(phn.balanceOf(recipient), got);
    }

    function testChronosPurchaseIsImmediatelyTransferable() public {
        vm.warp(CHRONOS);
        uint256 got = _buy(buyer, 1, 10_000_000 * USDC);
        assertEq(phn.transferableBalance(buyer), got);
        vm.prank(buyer); phn.transfer(recipient, got);
        assertEq(phn.balanceOf(recipient), got);
    }

    function testOionPurchaseIsImmediatelyTransferable() public {
        vm.warp(OION);
        uint256 got = _buy(buyer, 4, 10_000_000 * USDC);
        assertEq(phn.transferableBalance(buyer), got);
        vm.prank(buyer); phn.transfer(recipient, got);
        assertEq(phn.balanceOf(recipient), got);
    }

    function testFinalSealDoesNotRelockHolders() public {
        uint256 got = _buyKhaos(buyer);
        vm.warp(OION_CLOSE);
        assertEq(uint8(phn.protocolState()), uint8(PHANES.PublicState.FINAL_SEAL));
        vm.prank(buyer); phn.transfer(recipient, got / 2);
        assertEq(phn.balanceOf(recipient), got / 2);
        assertEq(phn.transferUnlockBps(), 10_000);
        assertTrue(phn.publicIssuanceFinalized());
    }

    function testSymbolicEmergenceCreatesNoHolderUnlockCliff() public {
        uint256 got = _buyKhaos(buyer);

        vm.warp(EMERGENCE - 1);
        assertEq(uint8(phn.protocolState()), uint8(PHANES.PublicState.FINAL_SEAL));
        assertEq(phn.transferUnlockBps(), 10_000);
        uint256 beforeBal = phn.transferableBalance(buyer);
        assertEq(beforeBal, got);

        vm.warp(EMERGENCE);
        assertEq(uint8(phn.protocolState()), uint8(PHANES.PublicState.EMERGED));
        assertEq(phn.transferUnlockBps(), 10_000);
        assertEq(phn.transferableBalance(buyer), beforeBal);
    }

    function testNextTransferMilestoneIsOnlyThe48HourGate() public {
        vm.warp(KHAOS);
        assertEq(phn.nextTransferMilestoneTimestamp(), TRADING_START);
        vm.warp(TRADING_START - 1);
        assertEq(phn.nextTransferMilestoneTimestamp(), TRADING_START);
        vm.warp(TRADING_START);
        assertEq(phn.nextTransferMilestoneTimestamp(), 0);
        vm.warp(OION_CLOSE);
        assertEq(phn.nextTransferMilestoneTimestamp(), 0);
    }

    function testFounderKhaosTrancheSharesTheSame48HourTransferGate() public {
        vm.warp(KHAOS);
        uint256 released = phn.founderVault().release();
        assertEq(released, 200_000 * UNIT);
        assertEq(phn.balanceOf(founder), 200_000 * UNIT);

        vm.expectRevert(PHANES.TransfersLocked.selector);
        vm.prank(founder); phn.transfer(recipient, 1);

        vm.warp(TRADING_START);
        vm.prank(founder); phn.transfer(recipient, 200_000 * UNIT);
        assertEq(phn.balanceOf(recipient), 200_000 * UNIT);
    }

    function testProtocolLiquidityAllocationDoesNotAutoDumpAtTradingOpen() public {
        uint256 liquidityBefore = phn.balanceOf(address(phn.liquidityVault()));
        assertEq(liquidityBefore, 2_000_000 * UNIT);

        _buyKhaos(buyer);
        vm.warp(TRADING_START);
        // Snapshot amount first so vm.prank is not consumed by nested balanceOf.
        uint256 half = phn.balanceOf(buyer) / 2;
        vm.prank(buyer);
        phn.transfer(recipient, half);

        assertEq(phn.balanceOf(address(phn.liquidityVault())), liquidityBefore);
    }

    function testPreGateScheduledAllocationBecomesFullyVestedAtGate() public {
        uint256 got = _buyKhaos(buyer);
        assertEq(phn.scheduledAllocation(buyer), got);
        assertEq(phn.scheduledVestedAmount(buyer, TRADING_START - 1), 0);
        assertEq(phn.scheduledVestedAmount(buyer, TRADING_START), got);
    }

    function testIncomingTokensAfterGateAreNeverRelocked() public {
        uint256 got = _buyKhaos(buyer);
        vm.warp(TRADING_START);
        uint256 q = got / 3;
        vm.prank(buyer); phn.transfer(buyer2, q);
        assertEq(phn.transferableBalance(buyer2), q);
        vm.prank(buyer2); phn.transfer(recipient, q);
        assertEq(phn.balanceOf(recipient), q);
    }

    function testFuzzFullBalanceTransferableAfterGate(uint96 rawAmount) public {
        uint256 got = _buyKhaos(buyer);
        vm.warp(TRADING_START);
        uint256 amount = bound(uint256(rawAmount), 0, got);
        vm.prank(buyer); phn.transfer(recipient, amount);
        assertEq(phn.balanceOf(recipient), amount);
        assertEq(phn.transferableBalance(buyer), got - amount);
        assertEq(phn.scheduledAllocationSpent(buyer), 0);
    }
}
