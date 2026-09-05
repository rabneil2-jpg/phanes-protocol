// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;
import "../src/PHANES_RC10_v0_8.sol";

interface VmBroadcast {
    function startBroadcast() external;
    function stopBroadcast() external;
}

/// @notice Guarded Base mainnet deployment wrapper for RC10 v0.8.
/// @dev Standalone Foundry script: no forge-std dependency. Mainnet use requires explicit founder authorisation after all release gates are green.
contract DeployRC10MainnetGuarded {
    VmBroadcast internal constant vm = VmBroadcast(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 constant BASE_MAINNET_CHAIN_ID = 8453;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant FOUNDER = 0xBE6D348d43083FC07BF4E453683AafF4da0C6a32;
    address constant R1 = 0xA4ac48B8eb1e639930Cc0ce3ACcAB5605D5DFe14;
    address constant R2 = 0x6Fff69C4d3Bf4590e2518ff3CdF07De567b8F4Dc;
    uint64 constant REWARDS_EXPIRY = 2_100_000_000;

    event DeploymentGraph(address core, address liquidity, address reserve, address founderVault, address launch, address rewards);

    function run() external returns (PHANES phn) {
        require(block.chainid == BASE_MAINNET_CHAIN_ID, "RC10: wrong chain");
        vm.startBroadcast();
        phn = new PHANES(USDC, FOUNDER, R1, R2, REWARDS_EXPIRY);
        vm.stopBroadcast();
        emit DeploymentGraph(address(phn), address(phn.liquidityVault()), address(phn.reserveVault()), address(phn.founderVault()), address(phn.launchEnablementVault()), address(phn.rewardsVault()));
    }
}
