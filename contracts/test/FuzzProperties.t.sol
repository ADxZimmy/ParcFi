// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ParcFiEscrow} from "../src/ParcFiEscrow.sol";
import {IParcFiEscrow} from "../src/interfaces/IParcFiEscrow.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// @notice Stateless fuzz properties over arbitrary amounts, splits, and durations —
///         the properties NF-05 names directly: rounding-free split conservation,
///         funding-partition behavior, and the exclusive challenge/finalize boundary.
contract FuzzPropertiesTest is Test {
    ParcFiEscrow internal escrow;
    MockUSDC internal usdc;

    address internal payer = makeAddr("f_payer");
    address internal attestor = makeAddr("f_attestor");
    address internal resolver = makeAddr("f_resolver");
    address internal beneficiary = makeAddr("f_beneficiary");

    function setUp() public {
        vm.warp(1_700_000_000);
        usdc = new MockUSDC();
        escrow = new ParcFiEscrow(address(usdc));
        usdc.mint(payer, type(uint128).max);
        vm.prank(payer);
        usdc.approve(address(escrow), type(uint256).max);
    }

    function _oneLine(uint256 amount, uint64 duration) internal returns (uint256 id) {
        IParcFiEscrow.ObligationInput[] memory obs = new IParcFiEscrow.ObligationInput[](1);
        obs[0] = IParcFiEscrow.ObligationInput(beneficiary, amount, bytes32("EV"), duration);
        vm.prank(payer);
        id = escrow.createAgreement(bytes32("DOC"), attestor, resolver, uint64(block.timestamp + 60 days), obs);
    }

    /// @notice For ANY amount and ANY split ≤ amount, resolution credits exactly the
    ///         obligation's amount across the two ledgers — no rounding gain or loss —
    ///         and both parties can drain the contract to zero.
    function testFuzz_ResolveSplitConservesExactly(uint96 rawAmount, uint96 rawSplit) public {
        uint256 amount = bound(uint256(rawAmount), 1, 1e15);
        uint256 split = bound(uint256(rawSplit), 0, amount);

        uint256 id = _oneLine(amount, 1 hours);
        vm.prank(payer);
        escrow.fund(id, amount);
        vm.prank(attestor);
        escrow.attest(id, 0, keccak256("ev"), bytes32("EV"));
        vm.prank(payer);
        escrow.challenge(id, 0);
        vm.prank(resolver);
        escrow.resolve(id, 0, split);

        assertEq(escrow.claimableOf(id, beneficiary) + escrow.refundableOf(id, payer), amount, "split lost value");
        assertEq(escrow.getAgreement(id).locked, 0, "resolved obligation still locked");

        if (split > 0) {
            vm.prank(beneficiary);
            escrow.claim(id);
        }
        if (split < amount) {
            vm.prank(payer);
            escrow.withdrawRefund(id);
        }
        assertEq(usdc.balanceOf(address(escrow)), 0, "contract not drained");
        assertEq(usdc.balanceOf(beneficiary), split, "beneficiary share wrong");
    }

    /// @notice For ANY two-line invoice and ANY partition point, partial funding never
    ///         latches, over-funding always reverts, and the exact remainder latches
    ///         with locked == requiredTotal.
    function testFuzz_FundingPartitionLatchesOnlyAtExactTotal(uint96 rawA, uint96 rawB, uint96 rawCut) public {
        uint256 a = bound(uint256(rawA), 1, 1e15);
        uint256 b = bound(uint256(rawB), 1, 1e15);
        uint256 total = a + b;
        uint256 cut = bound(uint256(rawCut), 1, total - 1);

        IParcFiEscrow.ObligationInput[] memory obs = new IParcFiEscrow.ObligationInput[](2);
        obs[0] = IParcFiEscrow.ObligationInput(beneficiary, a, bytes32("EV"), 1 hours);
        obs[1] = IParcFiEscrow.ObligationInput(beneficiary, b, bytes32("EV"), 1 hours);
        vm.prank(payer);
        uint256 id = escrow.createAgreement(bytes32("DOC"), attestor, resolver, uint64(block.timestamp + 60 days), obs);

        vm.prank(payer);
        escrow.fund(id, cut);
        assertFalse(escrow.getAgreement(id).fullyFunded, "partial funding latched");
        assertEq(escrow.getAgreement(id).locked, 0);

        vm.prank(payer);
        vm.expectRevert(IParcFiEscrow.OverFunding.selector);
        escrow.fund(id, total - cut + 1);

        vm.prank(payer);
        escrow.fund(id, total - cut);
        IParcFiEscrow.Agreement memory ag = escrow.getAgreement(id);
        assertTrue(ag.fullyFunded, "exact remainder did not latch");
        assertEq(ag.locked, total, "locked != requiredTotal at latch");
    }

    /// @notice For ANY challenge duration, the deadline boundary is exclusive and
    ///         gapless: strictly before it the payer can challenge and nobody can
    ///         finalize; at it, finalize succeeds and challenge reverts.
    function testFuzz_DeadlineBoundaryIsExclusiveAndGapless(uint32 rawDuration, bool challengeSide) public {
        uint64 duration = uint64(bound(uint256(rawDuration), 1, 30 days));
        uint256 id = _oneLine(1e6, duration);
        vm.prank(payer);
        escrow.fund(id, 1e6);
        vm.prank(attestor);
        escrow.attest(id, 0, keccak256("ev"), bytes32("EV"));
        uint64 deadline = escrow.getObligation(id, 0).challengeDeadline;

        vm.warp(deadline - 1);
        vm.expectRevert(IParcFiEscrow.ChallengeWindowOpen.selector);
        escrow.finalizeObligation(id, 0);

        if (challengeSide) {
            vm.prank(payer);
            escrow.challenge(id, 0);
            assertEq(uint256(escrow.getObligation(id, 0).status), uint256(IParcFiEscrow.ObligationStatus.Challenged));
        } else {
            vm.warp(deadline);
            vm.prank(payer);
            vm.expectRevert(IParcFiEscrow.ChallengeWindowClosed.selector);
            escrow.challenge(id, 0);
            escrow.finalizeObligation(id, 0);
            assertEq(escrow.claimableOf(id, beneficiary), 1e6);
        }
    }
}
