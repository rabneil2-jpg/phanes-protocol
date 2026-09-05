// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import "../src/PHANES_RC10_v0_8.sol";

interface VmBroadcast {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// @notice Base Sepolia rehearsal only. Uses Circle Base Sepolia USDC.
/// @dev Standalone Foundry script: no forge-std dependency.
contract DeployRC10SepoliaGuarded {
    VmBroadcast internal constant vm = VmBroadcast(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84532;
    address constant USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant FOUNDER = 0xBE6D348d43083FC07BF4E453683AafF4da0C6a32;
    address constant R1 = 0x64333a78f9b03C4e0bd2F0496ef3fF6c671211F8;
    address constant R2 = 0x8Abf9E6B52251C35E58C97daB6bb177A8876D471;
    uint64 constant REWARDS_EXPIRY = 2_100_000_000;

    event DeploymentGraph(address core, address liquidity, address reserve, address founderVault, address launch, address rewards);

    function run() external returns (PHANES phn) {
        require(block.chainid == BASE_SEPOLIA_CHAIN_ID, "RC10: wrong chain");
        vm.startBroadcast();
        phn = new PHANES(USDC, FOUNDER, R1, R2, REWARDS_EXPIRY);
        vm.stopBroadcast();
        emit DeploymentGraph(address(phn), address(phn.liquidityVault()), address(phn.reserveVault()), address(phn.founderVault()), address(phn.launchEnablementVault()), address(phn.rewardsVault()));
    }
}
