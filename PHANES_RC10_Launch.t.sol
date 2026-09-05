// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import "forge-std/Test.sol";
import "../src/PHANES_RC10_v0_8.sol";

contract PHANESRC10LaunchTest is Test {
    uint256 constant UNIT = 10_000;
    uint256 constant USDC = 1e6;
    uint64 constant KHAOS = 1_797_886_200;
    uint64 constant TRADING_START = 1_798_059_000;

    address founder = address(0xA001);
    address reviewer1 = address(0xA002);
    address reviewer2 = address(0xA003);
    address partner1 = address(0xB001);
    address partner2 = address(0xB002);

    MockUSDC usdc;
    PHANES phn;
    PHANESLaunchEnablementVault launch;
    PHANESRewardsVault rewards;

    
    bytes32 constant MANIFEST = keccak256("phanes-rc10-test-manifest");
    function _armLaunch() internal {
        vm.prank(founder); phn.approveReleaseManifest(MANIFEST);
        vm.prank(reviewer1); phn.approveReleaseManifest(MANIFEST);
        vm.prank(reviewer2); phn.approveReleaseManifest(MANIFEST);
        phn.armLaunch(MANIFEST);
    }

    function setUp() public {
        vm.warp(1_790_000_000);
        usdc = new MockUSDC(10_000_000 * USDC);
        phn = new PHANES(
            address(usdc),
            founder,
            reviewer1,
            reviewer2,
            uint64(2_100_000_000)
        );
        launch = phn.launchEnablementVault();
        rewards = phn.rewardsVault();

        usdc.transfer(partner1, 100_000 * USDC);
        vm.prank(partner1);
        usdc.approve(address(phn), type(uint256).max);
    
        _armLaunch();
    }

    function _approve(address recipient,uint256 amount)
        internal returns(uint64 id)
    {
        vm.prank(founder);
        id = launch.approveAllocation(
            recipient,
            uint128(amount),
            PHANESLaunchEnablementVault.Purpose.RegulatedDistribution,
            keccak256(abi.encode("agreement",recipient,amount)),
            keccak256(abi.encode("evidence",recipient,amount))
        );
    }

    function _bothReview(uint64 id) internal {
        vm.prank(reviewer1); launch.reviewAllocation(id);
        vm.prank(reviewer2); launch.reviewAllocation(id);
    }

    function testGenesisIsExactly21mWithRetainedAllocationSplit() public {
        assertEq(phn.totalSupply(),21_000_000*UNIT);
        assertEq(phn.balanceOf(address(phn)),17_000_000*UNIT);
        assertEq(phn.balanceOf(address(phn.liquidityVault())),2_000_000*UNIT);
        assertEq(phn.balanceOf(address(phn.founderVault())),1_000_000*UNIT);
        assertEq(phn.balanceOf(address(rewards)),750_000*UNIT);
        assertEq(phn.balanceOf(address(launch)),250_000*UNIT);
        assertEq(phn.balanceOf(address(phn.reserveVault())),0);
    }

    function testLaunchAllocationNeedsBothReviewers() public {
        uint64 id=_approve(partner1,100_000*UNIT);
        vm.prank(reviewer1); launch.reviewAllocation(id);
        vm.expectRevert(bytes("Launch: both reviews required"));
        vm.prank(partner1); launch.claimAllocation(id);

        vm.prank(reviewer2); launch.reviewAllocation(id);
        vm.prank(partner1); launch.claimAllocation(id);
        assertEq(phn.balanceOf(partner1),100_000*UNIT);
    }

    function testPrimaryCannotAllocateToSelfOrReviewers() public {
        address[3] memory blocked=[founder,reviewer1,reviewer2];
        for(uint256 i=0;i<blocked.length;i++){
            vm.expectRevert(bytes("Launch: blocked recipient"));
            vm.prank(founder);
            launch.approveAllocation(
                blocked[i],
                uint128(1_000*UNIT),
                PHANESLaunchEnablementVault.Purpose.LaunchOperations,
                keccak256("agreement"),
                keccak256("evidence")
            );
        }
    }

    function testEmptyAgreementOrEvidenceRejected() public {
        vm.expectRevert(bytes("Launch: agreement hash required"));
        vm.prank(founder);
        launch.approveAllocation(
            partner1, uint128(1_000*UNIT),
            PHANESLaunchEnablementVault.Purpose.SecurityAudit,
            bytes32(0), keccak256("e")
        );

        vm.expectRevert(bytes("Launch: evidence hash required"));
        vm.prank(founder);
        launch.approveAllocation(
            partner1, uint128(1_000*UNIT),
            PHANESLaunchEnablementVault.Purpose.SecurityAudit,
            keccak256("a"), bytes32(0)
        );
    }

    function testCancelledDealRestoresCapacityButMovesNoPHN() public {
        uint256 beforeBal=phn.balanceOf(address(launch));
        uint64 id=_approve(partner1,200_000*UNIT);
        vm.prank(founder);
        uint256 cancelled=launch.cancelAllocation(id);
        assertEq(cancelled,200_000*UNIT);
        assertEq(phn.balanceOf(address(launch)),beforeBal);

        uint64 id2=_approve(partner2,250_000*UNIT);
        _bothReview(id2);
        vm.prank(partner2); launch.claimAllocation(id2);
        assertEq(phn.balanceOf(partner2),250_000*UNIT);
    }

    function testCancelledAllocationCannotBeClaimed() public {
        uint64 id=_approve(partner1,50_000*UNIT);
        _bothReview(id);
        vm.prank(founder); launch.cancelAllocation(id);
        vm.expectRevert(bytes("Launch: not claimable"));
        vm.prank(partner1); launch.claimAllocation(id);
    }

    function testClaimAtOneSecondBeforeKhaosWorks() public {
        uint64 id=_approve(partner1,25_000*UNIT);
        _bothReview(id);
        vm.warp(KHAOS-1);
        vm.prank(partner1); launch.claimAllocation(id);
        assertEq(phn.balanceOf(partner1),25_000*UNIT);
    }

    function testClaimAtExactKhaosFails() public {
        uint64 id=_approve(partner1,25_000*UNIT);
        _bothReview(id);
        vm.warp(KHAOS);
        vm.expectRevert(bytes("Launch: claim expired"));
        vm.prank(partner1); launch.claimAllocation(id);
    }

    function testUnclaimedReturnsToRewardsAtExactKhaos() public {
        uint64 id=_approve(partner1,100_000*UNIT);
        _bothReview(id); // even fully reviewed but not claimed must expire

        vm.warp(KHAOS);
        uint256 moved=launch.returnUnusedToRewards();
        assertEq(moved,250_000*UNIT);
        assertEq(phn.balanceOf(address(launch)),0);
        assertEq(phn.balanceOf(address(rewards)),1_000_000*UNIT);

        vm.expectRevert(bytes("Launch: returned"));
        launch.returnUnusedToRewards();
    }

    function testPartialClaimMeansOnlyRemainderReturnsToRewards() public {
        uint64 id=_approve(partner1,75_000*UNIT);
        _bothReview(id);
        vm.prank(partner1); launch.claimAllocation(id);

        vm.warp(KHAOS);
        uint256 moved=launch.returnUnusedToRewards();
        assertEq(moved,175_000*UNIT);
        assertEq(phn.balanceOf(address(rewards)),925_000*UNIT);
        assertEq(phn.balanceOf(partner1),75_000*UNIT);
        assertEq(
            phn.balanceOf(partner1)+phn.balanceOf(address(rewards)),
            1_000_000*UNIT
        );
    }

    function testPartnerStillCannotTransferBefore48HourTradingStart() public {
        uint64 id=_approve(partner1,10_000*UNIT);
        _bothReview(id);
        vm.prank(partner1); launch.claimAllocation(id);

        vm.expectRevert(PHANES.TransfersLocked.selector);
        vm.prank(partner1); phn.transfer(partner2,1);

        vm.warp(TRADING_START);
        vm.prank(partner1); phn.transfer(partner2,1);
        assertEq(phn.balanceOf(partner2),1);
    }

    function testTotalLaunchClaimsCannotExceed250k() public {
        uint64 id=_approve(partner1,200_000*UNIT);
        _bothReview(id);
        vm.prank(partner1); launch.claimAllocation(id);

        vm.expectRevert(bytes("Launch: allocation cap"));
        vm.prank(founder);
        launch.approveAllocation(
            partner2, uint128(60_000*UNIT),
            PHANESLaunchEnablementVault.Purpose.SecurityAudit,
            keccak256("a2"),keccak256("e2")
        );
    }


    function testFirstKhaosBuyAutomaticallySweepsUnusedLaunchToRewards() public {
        assertEq(phn.balanceOf(address(launch)),250_000*UNIT);
        assertEq(phn.balanceOf(address(rewards)),750_000*UNIT);
        usdc.transfer(partner1,1_000_000*USDC);
        vm.prank(partner1); usdc.approve(address(phn),type(uint256).max);

        vm.warp(KHAOS);
        vm.prank(partner1);
        (uint256 spent,uint256 got)=phn.quoteForStage(0,10_000*USDC);
        assertGt(spent,0);
        assertGt(got,0);

        vm.prank(partner1);
        phn.buy(0,10_000*USDC,got,uint64(block.timestamp+60));

        assertTrue(launch.unusedReturned());
        assertEq(phn.balanceOf(address(launch)),0);
        assertEq(phn.balanceOf(address(rewards)),1_000_000*UNIT);
    }

    function testRewardsSunsetForcesLaunchSweepIfNobodyDidItAtKhaos() public {
        uint256 expiry=rewards.rewardsExpiryTime();
        uint256 liqBefore=phn.balanceOf(address(phn.liquidityVault()));

        vm.warp(expiry);
        uint256 moved=rewards.moveRemainingToLiquidityAfterExpiry();

        assertTrue(launch.unusedReturned());
        assertEq(phn.balanceOf(address(launch)),0);
        assertEq(phn.balanceOf(address(rewards)),0);
        assertEq(moved,1_000_000*UNIT);
        assertEq(phn.balanceOf(address(phn.liquidityVault())),liqBefore+1_000_000*UNIT);
    }

    function testFuzzLaunchRewardsConservation(uint128 amount) public {
        amount=uint128(bound(amount,1,250_000*UNIT));
        uint64 id=_approve(partner1,amount);
        _bothReview(id);
        vm.prank(partner1); launch.claimAllocation(id);
        vm.warp(KHAOS);
        launch.returnUnusedToRewards();

        assertEq(
            phn.balanceOf(partner1)+phn.balanceOf(address(rewards)),
            1_000_000*UNIT
        );
    }

}
