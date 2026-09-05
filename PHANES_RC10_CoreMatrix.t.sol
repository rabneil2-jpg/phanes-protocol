// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import "forge-std/Test.sol";
import "../src/PHANES_RC10_v0_8.sol";
import "./PHANES_ADVERSARIAL_PAYMENT_TOKENS_RC10.sol";

contract PHANESRC10CoreMatrixTest is Test {
    uint256 constant UNIT = 10_000;
    uint256 constant USDC = 1e6;

    uint64 constant KHAOS = 1_797_886_200;
    uint64 constant CHRONOS = 1_808_427_000;
    uint64 constant OION = 1_840_049_400;
    uint64 constant OION_CLOSE = 1_843_714_740;
    uint64 constant TRADING_START = 1_798_059_000;

    address founder = address(0xF001);
    address reviewer1 = address(0xF002);
    address reviewer2 = address(0xF003);
    address buyer = address(0xB001);
    address buyer2 = address(0xB002);
    address recipient = address(0xB003);

    MockUSDC usdc;
    PHANES phn;

    
    bytes32 constant MANIFEST = keccak256("phanes-rc10-test-manifest");
    function _armLaunch() internal {
        vm.prank(founder); phn.approveReleaseManifest(MANIFEST);
        vm.prank(reviewer1); phn.approveReleaseManifest(MANIFEST);
        vm.prank(reviewer2); phn.approveReleaseManifest(MANIFEST);
        phn.armLaunch(MANIFEST);
    }

    function setUp() public {
        vm.warp(1_790_000_000);
        usdc = new MockUSDC(100_000_000 * USDC);
        phn = new PHANES(
            address(usdc),
            founder,
            reviewer1,
            reviewer2,
            uint64(2_100_000_000)
        );
        usdc.transfer(buyer, 20_000_000 * USDC);
        usdc.transfer(buyer2, 20_000_000 * USDC);
        vm.prank(buyer);
        usdc.approve(address(phn), type(uint256).max);
        vm.prank(buyer2);
        usdc.approve(address(phn), type(uint256).max);
    
        _armLaunch();
    }

    function _buy(address who, uint8 stage, uint256 budget) internal returns(uint256 spent,uint256 got) {
        vm.prank(who);
        (spent,got) = phn.quoteForStage(stage,budget);
        if(got == 0) return (0,0);
        vm.prank(who);
        return phn.buy(stage,budget,got,uint64(block.timestamp+300));
    }

    function testGenesisExactly21m() public {
        assertEq(phn.totalSupply(),21_000_000*UNIT);
        assertEq(phn.balanceOf(address(phn)),17_000_000*UNIT);
        assertEq(phn.balanceOf(address(phn.liquidityVault())),2_000_000*UNIT);
        assertEq(phn.balanceOf(address(phn.founderVault())),1_000_000*UNIT);
        assertEq(phn.balanceOf(address(phn.rewardsVault())),750_000*UNIT);
        assertEq(phn.balanceOf(address(phn.launchEnablementVault())),250_000*UNIT);
        assertEq(phn.balanceOf(address(phn.reserveVault())),0);
    }

    function testEOAPaymentTokenRejectedAtConstruction() public {
        vm.expectRevert(PHANES.PaymentTokenHasNoCode.selector);
        new PHANES(address(0x1234), founder, reviewer1, reviewer2, uint64(2_100_000_000));
    }

    function testCurveEndpoints() public {
        assertEq(phn.currentIssuancePrice(),10_000);
        assertEq(phn.cumulativeCost(17_000_000*UNIT),860_823_333_333);
    }

    function testTransfersAndApprovalsLockedBeforeFirstPublicUnlock() public {
        vm.expectRevert(PHANES.TransfersLocked.selector);
        vm.prank(buyer);
        phn.transfer(buyer2,1);

        vm.expectRevert(PHANES.TransfersLocked.selector);
        vm.prank(buyer);
        phn.approve(buyer2,1);
    }

    function testKhaosOpeningEligibilityIs20Percent() public {
        vm.warp(KHAOS);
        assertEq(phn.normalEpochTimeEligible(0,KHAOS),1_000_000*UNIT);
        assertEq(phn.normalEpochCurrentlyPurchasable(0),1_000_000*UNIT);
    }

    function testKhaosEligibilityAt24HoursIs60Percent() public {
        vm.warp(KHAOS + 24 hours);
        assertEq(phn.normalEpochTimeEligible(0,block.timestamp),3_000_000*UNIT);
    }

    function testKhaosEligibilityAt48HoursIs100Percent() public {
        vm.warp(KHAOS + 48 hours);
        assertEq(phn.normalEpochTimeEligible(0,block.timestamp),5_000_000*UNIT);
    }

    function testSingleWalletCanAcquireEntireCurrentlyEligibleOpeningInventory() public {
        vm.warp(KHAOS);
        (,uint256 got)=phn.quoteForStage(0,10_000_000*USDC);
        assertEq(got,1_000_000*UNIT);
        _buy(buyer,0,10_000_000*USDC);
        assertEq(phn.publicSold(),1_000_000*UNIT);
        vm.prank(buyer);
        (uint256 spent2,uint256 got2)=phn.quoteForStage(0,10_000_000*USDC);
        assertEq(spent2,0);
        assertEq(got2,0);
    }

    function testMoreInventoryBecomesPurchasableAsGlobalEnvelopeStreams() public {
        vm.warp(KHAOS);
        _buy(buyer,0,10_000_000*USDC);
        vm.warp(KHAOS + 24 hours);
        (,uint256 got)=phn.quoteForStage(0,10_000_000*USDC);
        assertEq(got,2_000_000*UNIT);
    }

    function testPriceAdvancesGloballyAcrossPurchases() public {
        vm.warp(KHAOS);
        uint256 p0=phn.currentIssuancePrice();
        (,uint256 g1)=_buy(buyer,0,5_000*USDC);
        assertGt(g1,0);
        uint256 p1=phn.currentIssuancePrice();
        assertGt(p1,p0);
        (,uint256 g2)=_buy(buyer2,0,5_000*USDC);
        assertGt(g2,0);
        uint256 p2=phn.currentIssuancePrice();
        assertGt(p2,p1);
        assertLt(phn.publicSold(),1_000_000*UNIT);
    }

    function testStaleKhaosTransactionCannotCrossIntoChronos() public {
        vm.warp(CHRONOS-1);
        vm.prank(buyer);
        (,uint256 got)=phn.quoteForStage(0,100_000*USDC);
        assertGt(got,0);
        vm.warp(CHRONOS);
        vm.expectRevert(PHANES.IssuanceStageChanged.selector);
        vm.prank(buyer);
        phn.buy(0,100_000*USDC,0,uint64(block.timestamp+300));
    }

    function testUnsoldKhaosDoesNotInflateChronos() public {
        vm.warp(KHAOS);
        _buy(buyer,0,100_000*USDC);
        uint256 khaosSold=phn.normalEpochSold(0);
        vm.warp(CHRONOS);
        assertEq(phn.normalEpochAllocation(1),4_500_000*UNIT);
        assertEq(phn.oionAccumulated(),5_000_000*UNIT-khaosSold);
        assertEq(phn.normalEpochTimeEligible(1,CHRONOS),900_000*UNIT);
    }

    function testOionUsesLeftoversAndNoPriceReset() public {
        vm.warp(KHAOS);
        _buy(buyer,0,100_000*USDC);
        uint256 soldBefore=phn.publicSold();
        uint256 priceBefore=phn.currentIssuancePrice();

        vm.warp(OION);
        assertEq(phn.currentIssuanceStage(),4);
        assertGt(phn.finalOionAllocation(),0);
        assertEq(phn.publicSold(),soldBefore);
        assertEq(phn.currentIssuancePrice(),priceBefore);

        _buy(buyer2,4,100_000*USDC);
        assertGt(phn.currentIssuancePrice(),priceBefore);
    }

    function testFinalizationMovesAllUnsoldPublicToReserveWithoutBurn() public {
        vm.warp(OION_CLOSE);
        uint256 beforeSupply=phn.totalSupply();
        uint256 reserved=phn.finalizePublicIssuance();
        assertEq(phn.totalSupply(),beforeSupply);
        assertEq(reserved,17_000_000*UNIT);
        assertEq(phn.balanceOf(address(phn)),0);
        assertEq(phn.balanceOf(address(phn.reserveVault())),17_000_000*UNIT);
        assertEq(phn.reserveVault().originalReserve(),17_000_000*UNIT);
    }

    function testTradingStartUnlocksFullBalanceWithoutFinalizingPrimaryIssuance() public {
        vm.warp(KHAOS);
        _buy(buyer,0,50_000*USDC);
        uint256 bal=phn.balanceOf(buyer);
        assertGt(bal,0);

        vm.warp(TRADING_START);
        assertEq(phn.transferableBalance(buyer),bal);
        vm.prank(buyer);
        phn.transfer(buyer2,bal);
        assertEq(phn.balanceOf(buyer2),bal);
        assertEq(phn.transferableBalance(buyer),0);

        // Trading starts while the primary issuance programme is still open.
        assertFalse(phn.publicIssuanceFinalized());
        assertGt(phn.balanceOf(address(phn)),0);
    }

    function testFounderFirstTrancheExactly200kAtKhaos() public {
        vm.warp(KHAOS);
        uint256 amount=phn.founderVault().release();
        assertEq(amount,200_000*UNIT);
        assertEq(phn.balanceOf(founder),200_000*UNIT);
    }

    function testFounderCannotReleaseBeforeKhaos() public {
        vm.warp(KHAOS - 1);
        PHANESFounderVault fv=phn.founderVault();
        vm.expectRevert(bytes("FounderVault: none"));
        fv.release();
    }

    function testFounderFiveEpochTranchesTotal1m() public {
        uint64[5] memory opens = [uint64(KHAOS), uint64(CHRONOS), uint64(1_819_054_200), uint64(1_829_508_600), uint64(OION)];
        uint256 cumulative;
        for (uint256 i; i < 5; ++i) {
            vm.warp(opens[i]);
            uint256 amount = phn.founderVault().release();
            assertEq(amount, 200_000 * UNIT);
            cumulative += amount;
        }
        assertEq(cumulative, 1_000_000 * UNIT);
        assertEq(phn.balanceOf(founder), 1_000_000 * UNIT);
        assertEq(phn.balanceOf(address(phn.founderVault())), 0);
    }

    function testReserveHasNo2040Cliff() public {
        vm.warp(OION_CLOSE);
        phn.finalizePublicIssuance();
        PHANESReserveVault rv=phn.reserveVault();
        vm.warp(2_215_864_260);
        assertEq(rv.eligibleAmount(uint64(block.timestamp)),0);
        assertEq(rv.releasableToLiquidity(),0);
    }

    function testReserveReaches50PercentAt2045() public {
        vm.warp(OION_CLOSE);
        phn.finalizePublicIssuance();
        PHANESReserveVault rv=phn.reserveVault();
        vm.warp(2_373_630_660);
        assertEq(rv.eligibleAmount(uint64(block.timestamp)),rv.originalReserve()/2);
        uint256 liqBefore=phn.balanceOf(address(phn.liquidityVault()));
        uint256 released=rv.releaseEligibleToLiquidity();
        assertEq(released,rv.originalReserve()/2);
        assertEq(phn.balanceOf(address(phn.liquidityVault())),liqBefore+released);
    }

    function testTechnicalRewardNeedsReviewerOne() public {
        PHANESRewardsVault rw=phn.rewardsVault();
        vm.warp(KHAOS);
        vm.prank(founder);
        uint64 id=rw.createCampaign(
            PHANESRewardsVault.Category.Technical,
            uint128(100_000*UNIT),
            uint128(50_000*UNIT),
            10,
            uint64(block.timestamp),
            uint64(block.timestamp+30 days),
            keccak256("campaign")
        );
        bytes32 claimId=keccak256("technical-claim");
        vm.prank(founder);
        rw.approveClaim(id,recipient,claimId,uint128(10_000*UNIT),keccak256("evidence"));

        vm.expectRevert(bytes("Rewards: reviewer approvals missing"));
        vm.prank(recipient);
        rw.claimReward(claimId);

        vm.prank(reviewer1);
        rw.reviewClaim(claimId);
        vm.prank(recipient);
        rw.claimReward(claimId);
        assertEq(phn.balanceOf(recipient),10_000*UNIT);
    }

    function testLargeNonTechnicalNeedsBothReviewers() public {
        PHANESRewardsVault rw=phn.rewardsVault();
        vm.warp(KHAOS);
        vm.prank(founder);
        uint64 id=rw.createCampaign(
            PHANESRewardsVault.Category.Research,
            uint128(100_000*UNIT),
            uint128(100_000*UNIT),
            10,
            uint64(block.timestamp),
            uint64(block.timestamp+30 days),
            keccak256("research")
        );
        bytes32 claimId=keccak256("large-research");
        vm.prank(founder);
        rw.approveClaim(id,recipient,claimId,uint128(75_000*UNIT),keccak256("evidence2"));

        vm.prank(reviewer1);
        rw.reviewClaim(claimId);
        vm.expectRevert(bytes("Rewards: reviewer approvals missing"));
        vm.prank(recipient);
        rw.claimReward(claimId);

        vm.prank(reviewer2);
        rw.reviewClaim(claimId);
        vm.prank(recipient);
        rw.claimReward(claimId);
        assertEq(phn.balanceOf(recipient),75_000*UNIT);
    }

    function testDuplicateRewardClaimIdRejected() public {
        PHANESRewardsVault rw=phn.rewardsVault();
        vm.warp(KHAOS);
        vm.prank(founder);
        uint64 id=rw.createCampaign(
            PHANESRewardsVault.Category.Ecosystem,
            uint128(100_000*UNIT),
            uint128(25_000*UNIT),
            10,
            uint64(block.timestamp),
            uint64(block.timestamp+30 days),
            keccak256("eco")
        );
        bytes32 claimId=keccak256("dup");
        vm.prank(founder);
        rw.approveClaim(id,recipient,claimId,uint128(1_000*UNIT),keccak256("a"));
        vm.expectRevert(bytes("Rewards: claim id used"));
        vm.prank(founder);
        rw.approveClaim(id,buyer2,claimId,uint128(1_000*UNIT),keccak256("b"));
    }

    function testRewardsSunsetMovesRewardsPlusUnusedLaunchToLiquidity() public {
        PHANESRewardsVault rw=phn.rewardsVault();
        PHANESLaunchEnablementVault lv=phn.launchEnablementVault();
        uint256 expiry=rw.rewardsExpiryTime();
        uint256 rewardBal=phn.balanceOf(address(rw));
        uint256 launchBal=phn.balanceOf(address(lv));
        uint256 liqBefore=phn.balanceOf(address(phn.liquidityVault()));
        assertEq(rewardBal,750_000*UNIT);
        assertEq(launchBal,250_000*UNIT);

        vm.warp(expiry);
        uint256 moved=rw.moveRemainingToLiquidityAfterExpiry();

        assertTrue(lv.unusedReturned());
        assertEq(phn.balanceOf(address(lv)),0);
        assertEq(moved,rewardBal+launchBal);
        assertEq(phn.balanceOf(address(rw)),0);
        assertEq(phn.balanceOf(address(phn.liquidityVault())),liqBefore+rewardBal+launchBal);
    }

    function testFuzzCostIsMonotonic(uint256 a,uint256 b) public {
        a=bound(a,0,17_000_000*UNIT);
        b=bound(b,a,17_000_000*UNIT);
        assertLe(phn.cumulativeCost(a),phn.cumulativeCost(b));
    }

    function testFuzzCostPathTelescopes(uint256 a,uint256 b,uint256 c) public {
        a=bound(a,0,17_000_000*UNIT);
        b=bound(b,a,17_000_000*UNIT);
        c=bound(c,b,17_000_000*UNIT);
        assertEq(phn.costBetween(a,b)+phn.costBetween(b,c),phn.costBetween(a,c));
    }
}

contract PHANESRC10PaymentAdversarialTest is Test {

    function _armFor(PHANES p) internal {
        bytes32 m = keccak256("phanes-rc10-adv-manifest");
        vm.prank(founder); p.approveReleaseManifest(m);
        vm.prank(r1); p.approveReleaseManifest(m);
        vm.prank(r2); p.approveReleaseManifest(m);
        p.armLaunch(m);
    }
    uint256 constant UNIT=10_000;
    uint256 constant USDC=1e6;
    uint64 constant KHAOS=1_797_886_200;
    address founder=address(0xD1);
    address r1=address(0xD2);
    address r2=address(0xD3);
    address buyer=address(0xD4);

    function testFalseReturnPaymentRejected() public {
        vm.warp(1_790_000_000);
        FalseReturnPaymentToken t=new FalseReturnPaymentToken();
        PHANES p=new PHANES(address(t),founder,r1,r2,2_100_000_000);
        _armFor(p);
        t.mint(buyer,1_000_000*USDC);
        vm.prank(buyer); t.approve(address(p),type(uint256).max);
        vm.warp(KHAOS);
        vm.expectRevert(PHANES.TransferFailed.selector);
        vm.prank(buyer);
        p.buy(0,100_000*USDC,0,uint64(block.timestamp+60));
    }

    function testFeeOnTransferPaymentRejectedByBalanceDelta() public {
        vm.warp(1_790_000_000);
        FeeOnTransferPaymentToken t=new FeeOnTransferPaymentToken();
        PHANES p=new PHANES(address(t),founder,r1,r2,2_100_000_000);
        _armFor(p);
        t.mint(buyer,1_000_000*USDC);
        vm.prank(buyer); t.approve(address(p),type(uint256).max);
        vm.warp(KHAOS);
        vm.expectRevert(PHANES.PaymentMismatch.selector);
        vm.prank(buyer);
        p.buy(0,100_000*USDC,0,uint64(block.timestamp+60));
    }

    function testReentrantPaymentCannotNestedBuy() public {
        vm.warp(1_790_000_000);
        ReentrantPaymentToken t=new ReentrantPaymentToken();
        PHANES p=new PHANES(address(t),founder,r1,r2,2_100_000_000);
        _armFor(p);
        t.mint(buyer,1_000_000*USDC);
        vm.prank(buyer); t.approve(address(p),type(uint256).max);
        t.configure(address(p),0,1*USDC);
        vm.warp(KHAOS);
        vm.prank(buyer);
        p.buy(0,100_000*USDC,0,uint64(block.timestamp+60));
        assertGt(p.balanceOf(buyer),0);
    }
}
