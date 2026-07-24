// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ParcFiEscrow} from "../src/ParcFiEscrow.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

/// @notice Local development bootstrap: deploys MockUSDC + ParcFiEscrow against a
///         running anvil node and mints 1,000,000 demo USDC to the payer account
///         (anvil account #0). Paste the logged addresses into apps/web/.env.local.
///
///   anvil
///   forge script script/DeployLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast \
///     --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
contract DeployLocal is Script {
    function run() external {
        vm.startBroadcast();

        MockUSDC usdc = new MockUSDC();
        ParcFiEscrow escrow = new ParcFiEscrow(address(usdc));
        usdc.mint(msg.sender, 1_000_000e6);

        vm.stopBroadcast();

        console.log("NEXT_PUBLIC_USDC_ADDRESS=%s", address(usdc));
        console.log("NEXT_PUBLIC_ESCROW_ADDRESS=%s", address(escrow));
        console.log("Minted 1,000,000 demo USDC to %s", msg.sender);
    }
}
