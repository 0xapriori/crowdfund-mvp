// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/Treasury.sol";
import "../src/CrowdfundFactory.sol";

/// @title Deploy - Deploys the Crowdfund protocol (Treasury + Factory)
/// @notice Usage: forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerKey);

        // 1. Deploy Treasury with deployer as admin
        Treasury treasury = new Treasury(deployer);
        console.log("Treasury deployed at:", address(treasury));

        // 2. Deploy CrowdfundFactory with Treasury address
        CrowdfundFactory factory = new CrowdfundFactory(address(treasury));
        console.log("CrowdfundFactory deployed at:", address(factory));

        vm.stopBroadcast();

        // Summary
        console.log("--- Deployment Complete ---");
        console.log("Treasury:", address(treasury));
        console.log("Factory:", address(factory));
        console.log("Admin:", treasury.admin());
    }
}
