// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import "forge-std/Test.sol";
import "../src/PHANES_RC10_v0_8.sol";

contract PHANESRC10NoBuyerCapTest is Test {
    uint256 constant UNIT=10_000; uint256 constant USDC=1e6; uint64 constant KHAOS=1_797_886_200;
    address founder=address(0xA001); address r1=address(0xA002); address r2=address(0xA003); address buyer=address(0xB001);
    MockUSDC usdc; PHANES phn;
    
    bytes32 constant MANIFEST = keccak256("phanes-rc10-test-manifest");
    function _armLaunch() internal {
        vm.prank(founder); phn.approveReleaseManifest(MANIFEST);
        vm.prank(r1); phn.approveReleaseManifest(MANIFEST);
        vm.prank(r2); phn.approveReleaseManifest(MANIFEST);
        phn.armLaunch(MANIFEST);
    }

    function setUp() public {
        usdc=new MockUSDC(100_000_000*USDC);
        phn=new PHANES(address(usdc),founder,r1,r2,uint64(2_100_000_000));
        usdc.transfer(buyer,50_000_000*USDC);
        vm.prank(buyer); usdc.approve(address(phn),type(uint256).max);
        _armLaunch();
        vm.warp(KHAOS);
    }
    function _buy(uint256 budget) internal returns(uint256 got) { vm.prank(buyer); (uint256 spent,uint256 q)=phn.quoteForStage(0,budget); if(q==0)return 0; vm.prank(buyer); (,got)=phn.buy(0,budget,q,uint64(block.timestamp+300)); assertEq(got,q); assertGt(spent,0); }
    function testNo150kSinglePurchaseCeiling() public { vm.prank(buyer); (,uint256 q)=phn.quoteForStage(0,50_000_000*USDC); assertEq(q,1_000_000*UNIT); assertGt(q,150_000*UNIT); }
    function testNo150kCumulativeWalletStageCeiling() public { uint256 firstCost=phn.costBetween(0,400_000*UNIT); uint256 g1=_buy(firstCost); assertEq(g1,400_000*UNIT); uint256 g2=_buy(50_000_000*USDC); assertEq(g2,600_000*UNIT); assertEq(phn.publicSold(),1_000_000*UNIT); }
    function testGlobalEnvelopeStillCapsOpeningSupply() public { vm.prank(buyer); (,uint256 q)=phn.quoteForStage(0,type(uint128).max); assertEq(q,1_000_000*UNIT); vm.warp(KHAOS+24 hours); vm.prank(buyer); (,q)=phn.quoteForStage(0,type(uint128).max); assertEq(q,3_000_000*UNIT); }
}
