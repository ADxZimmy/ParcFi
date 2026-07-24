// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ParcFiEscrow} from "../src/ParcFiEscrow.sol";

/// @notice Fallback deployment path for Arc Testnet using a plain funded key.
///         The PRIMARY submission path is Circle Contracts (import the compiled
///         bytecode/ABI and deploy via the console or API — requirement F-12);
///         this script exists so a demo deployment is never blocked on that flow.
///
///   forge script script/DeployArc.s.sol --rpc-url https://rpc.testnet.arc.network \
///     --broadcast --private-key $DEPLOYER_KEY
///
///  Gas on Arc is paid in native USDC (18-decimal accounting); the deployer wallet
///  must hold Arc Testnet USDC from https://faucet.circle.com.
contract DeployArc is Script {
    /// @dev The 6-decimal ERC-20 interface of native USDC on Arc Testnet.
    address internal constant ARC_TESTNET_USDC = 0x3600000000000000000000000000000000000000;

    function run() external {
        vm.startBroadcast();
        ParcFiEscrow escrow = new ParcFiEscrow(ARC_TESTNET_USDC);
        vm.stopBroadcast();

        console.log("NEXT_PUBLIC_ESCROW_ADDRESS=%s", address(escrow));
        console.log("Explorer: https://testnet.arcscan.app/address/%s", address(escrow));
    }
}
