// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockUSDC
/// @notice Test double for Arc Testnet USDC: 6 decimals and an optional address
///         blocklist that mirrors real USDC's ability to freeze transfers. The
///         blocklist lets tests prove that one blocked beneficiary strands only its
///         own claim and never a sibling's entitlement (pull-payment isolation).
contract MockUSDC is ERC20 {
    mapping(address => bool) public blocked;

    constructor() ERC20("Mock USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setBlocked(address account, bool value) external {
        blocked[account] = value;
    }

    function _update(address from, address to, uint256 value) internal override {
        require(!blocked[from] && !blocked[to], "USDC: blocked");
        super._update(from, to, value);
    }
}
