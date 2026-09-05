// SPDX-License-Identifier: MIT
pragma solidity ^0.8.36;

import "../src/PHANES_RC10_v0_8.sol";

interface VmSafety {
    function warp(uint256) external;
    function prank(address) external;
    function expectRevert(bytes4) external;
}

contract PHANESRecoverySafetyPatchTest {
    VmSafety constant vm = VmSafety(address(uint160(uint256(keccak256("hevm cheat code")))));
    MockUSDC payment;
    PHANES phn;
    address founder = address(0xA11CE);
    address r1 = address(0xB0B);
    address r2 = address(0xCAFE);
    bytes32 manifest = keccak256("frozen-release-manifest");
    bytes32 reason = keccak256("abort-for-safety");

    function setUp() public {
        payment = new MockUSDC(1_000_000_000_000);
        phn = new PHANES(address(payment), founder, r1, r2, 2_100_000_000);
    }

    function _approveManifestAll() internal {
        vm.prank(founder); phn.approveReleaseManifest(manifest);
        vm.prank(r1); phn.approveReleaseManifest(manifest);
        vm.prank(r2); phn.approveReleaseManifest(manifest);
    }

    function testDeploymentStartsUnarmed() public { require(!phn.launchArmed()); require(!phn.launchAborted()); }

    function testCannotArmWithoutAllThreeManifestApprovals() public {
        vm.prank(founder); phn.approveReleaseManifest(manifest);
        vm.prank(r1); phn.approveReleaseManifest(manifest);
        vm.expectRevert(PHANES.ReleaseApprovalIncomplete.selector);
        phn.armLaunch(manifest);
    }

    function testPermissionlessArmAfterAllThreeApprovals() public {
        _approveManifestAll();
        phn.armLaunch(manifest);
        require(phn.launchArmed());
    }

    function testTwoOfThreeCanPermanentlyAbortBeforeKhaos() public {
        vm.prank(founder); phn.approveLaunchAbort(reason);
        vm.prank(r1); phn.approveLaunchAbort(reason);
        phn.executeLaunchAbort(reason);
        require(phn.launchAborted());
        require(!phn.launchArmed());
        vm.expectRevert(PHANES.ReleaseSafetyClosed.selector);
        phn.armLaunch(manifest);
    }

    function testUnarmedAtKhaosIsDeadState() public {
        vm.warp(phn.KHAOS_START());
        require(uint8(phn.protocolState()) == uint8(PHANES.PublicState.ABORTED));
        require(phn.currentIssuanceStage() == type(uint8).max);
    }

    function testAbortCannotExecuteAtOrAfterKhaos() public {
        vm.prank(founder); phn.approveLaunchAbort(reason);
        vm.prank(r1); phn.approveLaunchAbort(reason);
        vm.warp(phn.KHAOS_START());
        vm.expectRevert(PHANES.ReleaseSafetyClosed.selector);
        phn.executeLaunchAbort(reason);
    }

    function testQuoteZeroWhileUnarmed() public {
        vm.warp(phn.KHAOS_START());
        (uint256 spent,uint256 got)=phn.quote(1_000_000);
        require(spent==0 && got==0);
    }
}
